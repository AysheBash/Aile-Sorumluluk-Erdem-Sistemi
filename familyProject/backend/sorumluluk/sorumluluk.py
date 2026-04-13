import os
from flask import Flask, jsonify, request, send_from_directory
import psycopg2
from flask_cors import CORS
import datetime
from werkzeug.utils import secure_filename 

app = Flask(__name__)
CORS(app)

# Resim ayarları
UPLOAD_FOLDER = 'uploads'
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

def get_db_connection():
    return psycopg2.connect(
        host="localhost", 
        database="AileveProfilSistemi",
        user="aysebas", 
        password="1234"
    )

@app.route('/uploads/<filename>')
def uploaded_file(filename):
    return send_from_directory(app.config['UPLOAD_FOLDER'], filename)

# --- 1. AUTH (KAYIT/GİRİŞ) ---

@app.route('/register', methods=['POST'])
def register():
    data = request.json
    family_name = data.get('family_name')
    email = data.get('email')
    password = data.get('password')
    
    conn = None
    try:
        conn = get_db_connection(); cur = conn.cursor()
        
        # 1. Kontrol: Bu e-posta daha önce alınmış mı?
        cur.execute('SELECT id FROM families WHERE email = %s', (email,))
        if cur.fetchone():
            return jsonify({"status": "error", "message": "Bu e-posta adresi zaten kullanımda."}), 400

        # 2. Kayıt: Aileyi ekle
        cur.execute('INSERT INTO families (aile_adi, email, sifre_hash) VALUES (%s, %s, %s) RETURNING id;',
                    (family_name, email, password))
        family_id = cur.fetchone()[0]

        # 3. Rolü bul ve Admin kullanıcısını oluştur
        cur.execute("SELECT id FROM roles WHERE LOWER(role_name) = 'ebeveyn' LIMIT 1;")
        role_res = cur.fetchone()
        role_id = role_res[0] if role_res else 1
        
        cur.execute("INSERT INTO users (family_id, role_id, isim) VALUES (%s, %s, %s);", 
                    (family_id, role_id, "Admin"))
        
        conn.commit()
        return jsonify({"family_id": int(family_id), "status": "success"}), 201
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({"status": "error", "message": "Kayıt sırasında bir hata oluştu: " + str(e)}), 400
    finally:
        if conn: cur.close(); conn.close()

@app.route('/login', methods=['POST'])
def login():
    data = request.json
    email = data.get('email')
    password = data.get('password')
    
    conn = None
    try:
        conn = get_db_connection(); cur = conn.cursor()
        
        # 1. Adım: E-posta adresini sorgula
        cur.execute('SELECT id, sifre_hash FROM families WHERE email = %s', (email,))
        family = cur.fetchone()
        
        if not family:
            # Kullanıcı yoksa SwiftUI'ya bu mesaj gidecek ✨
            return jsonify({"status": "error", "message": "Bu e-posta adresi sistemde kayıtlı değil."}), 401
        
        family_id, stored_password = family
        
        # 2. Adım: Şifreyi kontrol et
        if stored_password != password:
            # Şifre yanlışsa SwiftUI'ya bu mesaj gidecek ✨
            return jsonify({"status": "error", "message": "Girdiğiniz şifre hatalı. Lütfen kontrol edin."}), 401
            
        # Giriş başarılı
        return jsonify({"family_id": int(family_id), "status": "success"}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": "Sunucu hatası: " + str(e)}), 500
    finally:
        if conn: cur.close(); conn.close()

# --- 2. PROFİL VE KULLANICI YÖNETİMİ ---
@app.route('/users/<int:family_id>', methods=['GET'])
def get_users(family_id):
    conn = get_db_connection(); cur = conn.cursor()
    cur.execute('SELECT u.id, u.isim, r.role_name, u.profil_resmi FROM users u JOIN roles r ON u.role_id = r.id WHERE u.family_id = %s ORDER BY u.id ASC', (family_id,))
    users = [{"id": r[0], "isim": r[1], "role": r[2], "avatar": r[3]} for r in cur.fetchall()]
    cur.close(); conn.close()
    return jsonify(users)

@app.route('/add_user', methods=['POST'])
def add_user():
    data = request.json
    conn = None
    try:
        conn = get_db_connection(); cur = conn.cursor()
        cur.execute("INSERT INTO users (family_id, role_id, isim) VALUES (%s, %s, %s);", 
                    (data['family_id'], data['role_id'], data['isim']))
        conn.commit()
        return jsonify({"status": "success"}), 201
    except Exception as e: return jsonify({"status": "error", "message": str(e)}), 400
    finally:
        if conn: cur.close(); conn.close()

# --- 3. GÖREV YÖNETİMİ ---
@app.route('/tasks/<int:user_id>', methods=['GET'])
def get_tasks(user_id):
    conn = get_db_connection(); cur = conn.cursor()
    # Sadece is_active = TRUE olanları getiriyoruz ✨
    cur.execute('''SELECT id, title, default_point, is_erdem, description 
                   FROM tasks 
                   WHERE assigned_to = %s AND is_active = TRUE 
                   ORDER BY id DESC;''', (user_id,))
    tasks = [{"id": r[0], "title": r[1], "points": r[2], "is_erdem": r[3], "description": r[4]} for r in cur.fetchall()]
    cur.close(); conn.close()
    return jsonify(tasks)

@app.route('/add_task', methods=['POST'])
def add_task():
    data = request.json
    conn = get_db_connection(); cur = conn.cursor()
    cur.execute('INSERT INTO tasks (title, default_point, assigned_to, is_erdem, description) VALUES (%s, %s, %s, %s, %s)',
                (data['title'], data['points'], data['assigned_to'], data['is_erdem'], data.get('description', '')))
    conn.commit(); cur.close(); conn.close()
    return jsonify({"status": "success"})

# --- 4. ONAY VE PUAN SİSTEMİ ---
@app.route('/complete_task', methods=['POST'])
def complete_task():
    u_id, t_id, pts = request.form.get('user_id'), request.form.get('task_id'), request.form.get('points')
    file = request.files.get('image')
    filename = None
    if file:
        filename = secure_filename(f"proof_{u_id}_{t_id}_{datetime.datetime.now().strftime('%Y%m%d%H%M%S')}.jpg")
        file.save(os.path.join(app.config['UPLOAD_FOLDER'], filename))
    conn = get_db_connection(); cur = conn.cursor()
    try:
        cur.execute('''INSERT INTO task_completions (user_id, task_id, earned_point, status, proof_image) 
                       VALUES (%s, %s, %s, 'pending', %s)''', (u_id, t_id, pts, filename))
        conn.commit()
        return jsonify({"status": "pending"}), 201
    except Exception as e:
        conn.rollback(); return jsonify({"status": "error", "message": str(e)}), 400
    finally: cur.close(); conn.close()

@app.route('/pending_tasks/<int:family_id>', methods=['GET'])
def get_pending_tasks(family_id):
    conn = get_db_connection(); cur = conn.cursor()
    cur.execute('''SELECT tc.id, u.isim, t.title, tc.earned_point, tc.proof_image FROM task_completions tc 
                   JOIN users u ON tc.user_id = u.id JOIN tasks t ON tc.task_id = t.id 
                   WHERE u.family_id = %s AND tc.status = 'pending' ''', (family_id,))
    pending = [{"id": r[0], "user_name": r[1], "task_title": r[2], "points": r[3], "image": r[4]} for r in cur.fetchall()]
    cur.close(); conn.close()
    return jsonify(pending)

@app.route('/approve_task/<int:pending_id>', methods=['POST'])
def approve_task(pending_id):
    conn = get_db_connection(); cur = conn.cursor()
    try:
        # Önce görev ID'sini ve diğer bilgileri alalım
        cur.execute('SELECT tc.user_id, tc.earned_point, t.is_erdem, tc.task_id FROM task_completions tc JOIN tasks t ON tc.task_id = t.id WHERE tc.id = %s', (pending_id,))
        res = cur.fetchone()
        if not res: return jsonify({"error": "Kayıt bulunamadı"}), 404
        
        user_id, pts, is_erdem, task_id = res
        week = datetime.date.today().isocalendar()[1]

        # 1. Haftalık puanı güncelle
        cur.execute('''INSERT INTO user_weekly_points (user_id, week_no, responsibility_points) VALUES (%s, %s, %s)
                       ON CONFLICT (user_id, week_no) DO UPDATE SET responsibility_points = user_weekly_points.responsibility_points + EXCLUDED.responsibility_points''', (user_id, week, pts))

        # 2. Erdem ise rozet ekle
        if is_erdem:
            cur.execute("SELECT id FROM badges WHERE badge_name = 'Erdem Rozeti' LIMIT 1")
            badge_res = cur.fetchone()
            badge_id = badge_res[0] if badge_res else 1
            cur.execute('INSERT INTO user_badges (user_id, badge_id, badge_points, earned_date) VALUES (%s, %s, %s, NOW())', (user_id, badge_id, pts))

        # 3. GÖREVİ TEK KULLANIMLIK YAP (PASİFE ÇEK) ✨
        cur.execute("UPDATE tasks SET is_active = FALSE WHERE id = %s", (task_id,))

        # 4. Onay durumunu güncelle
        cur.execute("UPDATE task_completions SET status = 'approved' WHERE id = %s", (pending_id,))
        
        conn.commit()
        return jsonify({"status": "success"}), 200
    except Exception as e:
        conn.rollback(); return jsonify({"error": str(e)}), 500
    finally: cur.close(); conn.close()
    

@app.route('/reject_task/<int:completion_id>', methods=['POST'])
def reject_task(completion_id):
    conn = get_db_connection(); cur = conn.cursor()
    cur.execute("UPDATE task_completions SET status = 'rejected' WHERE id = %s", (completion_id,))
    conn.commit(); cur.close(); conn.close()
    return jsonify({"status": "success"})

# --- 5. İSTATİSTİKLER VE GEÇMİŞ ---
@app.route('/point_history/<int:user_id>', methods=['GET'])
def get_point_history(user_id):
    conn = get_db_connection(); cur = conn.cursor()
    cur.execute('''SELECT tc.earned_point, t.title, tc.completion_date FROM task_completions tc 
                   JOIN tasks t ON tc.task_id = t.id WHERE tc.user_id = %s AND tc.status = 'approved' 
                   ORDER BY tc.completion_date DESC''', (user_id,))
    res = [{"amount": r[0], "desc": r[1], "date": r[2].strftime('%d %b %H:%M'), "type": "Görev"} for r in cur.fetchall()]
    cur.close(); conn.close()
    return jsonify(res)

@app.route('/user_badges/<int:user_id>', methods=['GET'])
def get_user_badges(user_id):
    conn = get_db_connection(); cur = conn.cursor()
    cur.execute('''SELECT b.badge_name, ub.earned_date, b.required_points FROM user_badges ub 
                   JOIN badges b ON ub.badge_id = b.id WHERE ub.user_id = %s''', (user_id,))
    badges = [{"name": r[0], "date": r[1].strftime('%d.%m.%Y'), "points": r[2]} for r in cur.fetchall()]
    cur.close(); conn.close()
    return jsonify(badges)

@app.route('/stats/<int:family_id>', methods=['GET'])
def get_family_stats(family_id): 
    conn = get_db_connection(); cur = conn.cursor()
    current_week = datetime.date.today().isocalendar()[1]
    
    try:
        cur.execute('''
            SELECT u.id, u.isim, 
            -- Bu haftanın normal sorumluluk puanı
            COALESCE((SELECT responsibility_points FROM user_weekly_points WHERE user_id = u.id AND week_no = %s), 0) as week_total,
            -- Bu haftanın erdem puanı (Sadece bu haftaki task_completions üzerinden) ✨
            COALESCE((
                SELECT SUM(tc.earned_point) 
                FROM task_completions tc 
                JOIN tasks t ON tc.task_id = t.id 
                WHERE tc.user_id = u.id 
                AND t.is_erdem = TRUE 
                AND tc.status = 'approved'
                AND tc.completion_date >= CURRENT_DATE - (EXTRACT(DOW FROM CURRENT_DATE)::int || ' days')::interval
            ), 0) as week_erdem
            FROM users u WHERE u.family_id = %s;
        ''', (current_week, family_id))
        
        stats = [{"id": r[0], "isim": r[1], "total": r[2], "erdem": r[3]} for r in cur.fetchall()]
        return jsonify(stats)
    finally: cur.close(); conn.close()
    
    
@app.route('/family_info/<int:f_id>', methods=['GET'])
def get_family_info(f_id):
    conn = get_db_connection(); cur = conn.cursor()
    cur.execute("SELECT aile_adi, weekly_main_event, event_detail FROM families WHERE id = %s", (f_id,))
    r = cur.fetchone()
    cur.close(); conn.close()
    if r: return jsonify({"family_name": r[0], "weekly_main_event": r[1], "event_detail": r[2]})
    return jsonify({"error": "Bulunamadı"}), 404

# --- 6. ETKİNLİK VE KARAR VERİCİ MEKANİZMASI ---
@app.route('/family_decision_maker/<int:family_id>', methods=['GET'])
def get_decision_maker(family_id):
    conn = get_db_connection(); cur = conn.cursor()
    try:
        # Bu haftanın ilk rozetini alan çocuğu bulur
        week_start = datetime.date.today() - datetime.timedelta(days=datetime.date.today().weekday())
        cur.execute('''SELECT u.id, u.isim FROM user_badges ub JOIN users u ON ub.user_id = u.id 
                       WHERE u.family_id = %s AND ub.earned_date >= %s ORDER BY ub.earned_date ASC LIMIT 1''', (family_id, week_start))
        res = cur.fetchone()
        if res: return jsonify({"user_id": res[0], "isim": res[1]})
        return jsonify({"user_id": None, "isim": "Rozet kazanan bekleniyor..."})
    finally: cur.close(); conn.close()

@app.route('/update_event', methods=['POST'])
def update_event():
    data = request.json
    conn = get_db_connection(); cur = conn.cursor()
    try:
        cur.execute("UPDATE families SET weekly_main_event = %s, event_detail = 'Karar bekleniyor...' WHERE id = %s", 
                    (data.get('event_name'), data.get('family_id')))
        conn.commit()
        return jsonify({"status": "success"}), 200
    finally: cur.close(); conn.close()

@app.route('/update_event_detail', methods=['POST'])
def update_event_detail():
    data = request.json
    conn = get_db_connection(); cur = conn.cursor()
    try:
        cur.execute("UPDATE families SET event_detail = %s WHERE id = %s", (data.get('detail'), data.get('family_id')))
        conn.commit()
        return jsonify({"status": "success"}), 200
    finally: cur.close(); conn.close()

# --- 7. YILLIK PERFORMANS VE ŞAMPİYON ---
@app.route('/weekly_champion/<int:family_id>', methods=['GET'])
def get_weekly_champion(family_id):
    week = datetime.date.today().isocalendar()[1]
    conn = get_db_connection(); cur = conn.cursor()
    cur.execute('''SELECT u.isim, wp.responsibility_points FROM user_weekly_points wp 
                   JOIN users u ON wp.user_id = u.id WHERE u.family_id = %s AND wp.week_no = %s
                   ORDER BY wp.responsibility_points DESC LIMIT 1''', (family_id, week))
    res = cur.fetchone()
    cur.close(); conn.close()
    return jsonify({"isim": res[0], "puan": res[1]}) if res else jsonify({"isim": "---", "puan": 0})

@app.route('/family_yearly_stats/<int:family_id>', methods=['GET'])
def get_family_yearly_stats(family_id):
    conn = get_db_connection(); cur = conn.cursor()
    cur.execute('''SELECT week_no, SUM(responsibility_points) FROM user_weekly_points wp
                   JOIN users u ON wp.user_id = u.id WHERE u.family_id = %s GROUP BY week_no''', (family_id,))
    stats = {str(r[0]): {"puan": r[1]} for r in cur.fetchall()}
    cur.close(); conn.close()
    return jsonify(stats)

# --- SİLME VE DÜZENLEME ROTALARI ---

@app.route('/delete_user/<int:user_id>', methods=['DELETE'])
def delete_user(user_id):
    conn = get_db_connection(); cur = conn.cursor()
    try:
        cur.execute("DELETE FROM users WHERE id = %s", (user_id,))
        conn.commit()
        return jsonify({"status": "success"}), 200
    except Exception as e:
        conn.rollback(); return jsonify({"error": str(e)}), 400
    finally: cur.close(); conn.close()

@app.route('/delete_task/<int:task_id>', methods=['DELETE'])
def delete_task(task_id):
    conn = get_db_connection(); cur = conn.cursor()
    try:
        cur.execute("DELETE FROM tasks WHERE id = %s", (task_id,))
        conn.commit()
        return jsonify({"status": "success"}), 200
    except Exception as e:
        conn.rollback(); return jsonify({"error": str(e)}), 400
    finally: cur.close(); conn.close()

if __name__ == '__main__':
    app.run(debug=True, port=5000)