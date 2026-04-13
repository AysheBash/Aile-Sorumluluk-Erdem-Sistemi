//
//  ContentView.swift
//  sorumluluk
//
//  Created by Ayse Bas on 10.03.2026.
//
import SwiftUI
import UIKit
import Lottie

// MARK: - 1. MODELLER
struct FamilyMember: Identifiable, Codable {
    let id: Int; let isim: String; let role: String; var avatar: String?
}
struct TaskItem: Identifiable, Codable {
    let id: Int; let title: String; let points: Int; let is_erdem: Bool; let description: String?
}
struct MemberStat: Identifiable, Codable {
    let id: Int; let isim: String; let total: Int; let erdem: Int
}
struct Champion: Codable {
    let isim: String; let puan: Int
}
struct PendingTask: Identifiable, Codable {
    let id: Int; let user_name: String; let task_title: String; let points: Int; let image: String?
}
struct PointLog: Identifiable, Codable {
    var id: UUID? = UUID()
    let amount: Int; let type: String; let desc: String; let date: String
    enum CodingKeys: String, CodingKey { case amount, type, desc, date }
}
struct Badge: Identifiable, Codable {
    var id: UUID? = UUID()
    let name: String; let date: String; let points: Int
    enum CodingKeys: String, CodingKey { case name, date, points }
}
struct ActivityItem: Identifiable {
    let id = UUID(); let title: String; let imageName: String; let category: String
}

// MARK: - RENK PALETİ
extension Color {
    static let appBg = Color(hex: "FFF8E7")
    static let cardBg = Color(hex: "FFFFFF")
    static let titleColor = Color(hex: "FF9E6D")
    static let btnBlue = Color(hex: "7EC8E3")
    static let backBtn = Color(hex: "8ED1B2")
    static let textMain = Color(hex: "4A4A4A")
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        r = (int >> 16) & 0xFF; g = (int >> 8) & 0xFF; b = int & 0xFF
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: 1)
    }
}

// MARK: - 2. YARDIMCI BİLEŞENLER
struct LottieView: UIViewRepresentable {
    var name: String
    var loopMode: LottieLoopMode = .loop
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let animationView = LottieAnimationView(name: name)
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = loopMode
        animationView.play()
        animationView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(animationView)
        NSLayoutConstraint.activate([
            animationView.heightAnchor.constraint(equalTo: view.heightAnchor),
            animationView.widthAnchor.constraint(equalTo: view.widthAnchor),
            animationView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            animationView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct ActivityCard: View {
    let activity: ActivityItem; let isSelected: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Image(activity.imageName).resizable().aspectRatio(contentMode: .fill).frame(width: 280, height: 180).clipped()
                if isSelected { Circle().fill(Color.backBtn).frame(width: 40, height: 40).overlay(Image(systemName: "checkmark").foregroundColor(.white).font(.system(size: 20, weight: .bold))).padding(15).shadow(radius: 5) }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(activity.category.uppercased()).font(.system(size: 12, weight: .bold)).foregroundColor(.titleColor).padding(.horizontal, 4)
                Text(activity.title).font(.system(size: 22, weight: .black)).foregroundColor(.textMain).lineLimit(1)
            }.padding(15)
        }.frame(width: 280).background(Color.white).cornerRadius(25).shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 5)
        .overlay(RoundedRectangle(cornerRadius: 25).stroke(isSelected ? Color.titleColor : Color.clear, lineWidth: 4))
    }
}

struct ProgressCircleView: View {
    let value: Int; let target: Int; let title: String; let color: Color
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(Color.black.opacity(0.05), lineWidth: 8)
                Circle().trim(from: 0, to: CGFloat(min(Double(value) / Double(max(target, 1)), 1.0)))
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round)).rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("\(value)").font(.system(size: 14, weight: .bold)).foregroundColor(.textMain)
                    Divider().frame(width: 20).background(Color.textMain.opacity(0.3))
                    Text("\(target)").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                }
            }.frame(width: 85, height: 85)
            Text(title).font(.system(size: 11, weight: .bold)).foregroundColor(.textMain)
        }
    }
}

// MARK: - 3. ANA YÖNETİCİ
struct ContentView: View {
    @State private var familyId: Int? = nil; @State private var currentUser: FamilyMember? = nil; @State private var showSplash = true
    var body: some View {
        ZStack {
            if showSplash {
                VStack { LottieView(name: "splash_animation").frame(width: 300, height: 300) }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.appBg).onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { withAnimation { showSplash = false } } }
            } else {
                if familyId == nil { AuthView(familyId: $familyId) }
                else if currentUser == nil { ProfileSelectionView(familyId: familyId!, selectedUser: $currentUser) { familyId = nil } }
                else { MainAppView(familyId: familyId!, user: currentUser!) { currentUser = nil } }
            }
        }
    }
}

// MARK: - 4. MAINAPPVIEW
struct MainAppView: View {
    let familyId: Int; let user: FamilyMember; var onBack: () -> Void
    @State private var tasks: [TaskItem] = []; @State private var stats: [MemberStat] = []
    @State private var champion: Champion = Champion(isim: "---", puan: 0)
    @State private var weeklyMainEvent: String = "Film Gecesi 🎬"; @State private var eventDetail: String = "Karar bekleniyor..."
    @State private var yearlyStats: [String: [String: Any]] = [:]
    @State private var showAdd = false; @State private var showApproval = false; @State private var showCamera = false
    @State private var selectedTask: TaskItem? = nil; @State private var inputImage: UIImage? = nil
    @State private var pendingCount: Int = 0

    var body: some View {
        TabView {
            NavigationView {
                ZStack {
                    Color.appBg.ignoresSafeArea()
                    List(tasks) { task in
                        taskRow(task: task)
                    }
                    .listStyle(PlainListStyle())
                    .refreshable { loadData() }
                }
                .navigationTitle("\(user.isim)").toolbar {
                    ToolbarItem(placement: .navigationBarLeading) { Button("Geri", action: onBack).foregroundColor(.backBtn).bold() }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if user.role.lowercased() == "ebeveyn" {
                            HStack(spacing: 15) {
                                Button(action: { showApproval = true }) { Image(systemName: "bell.fill").foregroundColor(.titleColor).overlay(pendingCount > 0 ? Circle().fill(.red).frame(width: 8, height: 8).offset(x: 8, y: -8) : nil) }
                                Button(action: { showAdd = true }) { Image(systemName: "plus.circle.fill").foregroundColor(.titleColor) }
                            }
                        }
                    }
                }
            }.tabItem { Label("Görevler", systemImage: "checklist") }

            NavigationView {
                ZStack {
                    Color.appBg.ignoresSafeArea()
                    ScrollView {
                        VStack(spacing: 20) {
                            StatsDashboardView(stats: stats, champion: champion, erdemScore: stats.first(where: {$0.id == user.id})?.erdem ?? 0, familyTotal: stats.reduce(0){$0 + $1.total}, userCurrentScore: stats.first(where: {$0.id == user.id})?.total ?? 0, individualTarget: 500, mainEvent: weeklyMainEvent, eventDetail: eventDetail)
                            YearGridView(familyStats: yearlyStats)
                            HStack(spacing: 15) {
                                NavigationLink(destination: PointHistoryView(userId: user.id)) {
                                    Label("Geçmiş", systemImage: "clock.arrow.circlepath").font(.headline).frame(maxWidth: .infinity).padding().background(Color.white).cornerRadius(15).shadow(radius: 2)
                                }
                                NavigationLink(destination: BadgeGalleryView(userId: user.id)) {
                                    Label("Rozetler", systemImage: "trophy.fill").font(.headline).frame(maxWidth: .infinity).padding().background(Color.white).cornerRadius(15).shadow(radius: 2)
                                }
                            }.padding(.horizontal)
                        }
                    }
                }.navigationTitle("İstatistikler").onAppear { loadData() }
            }.tabItem { Label("Puanlar", systemImage: "chart.bar.fill") }

            NavigationView {
                ActivityDetailView(user: user, familyId: familyId, mainEvent: $weeklyMainEvent, eventDetail: $eventDetail, saveEvent: saveMainEventToDB, saveDetail: saveEventDetailToDB)
            }.tabItem { Label("Etkinlik", systemImage: "sparkles") }
        }
        .accentColor(.titleColor)
        .onAppear(perform: loadData)
        .sheet(isPresented: $showAdd) { AddTaskView(familyId: familyId) { loadData() } }
        .sheet(isPresented: $showApproval) { ApprovalRoomView(familyId: familyId) { loadData() } }
        .sheet(isPresented: $showCamera, onDismiss: uploadProof) { ImagePicker(image: $inputImage) }
    }

    private func taskRow(task: TaskItem) -> some View {
        HStack(spacing: 15) {
            Image(systemName: task.is_erdem ? "heart.fill" : "circle.fill").foregroundColor(task.is_erdem ? .titleColor : .btnBlue)
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title).font(.system(size: 16, weight: .bold)).foregroundColor(.textMain)
                if let desc = task.description { Text(desc).font(.caption).foregroundColor(.secondary) }
            }
            Spacer()
            Button(action: { selectedTask = task; showCamera = true }) {
                HStack(spacing: 4) { Text("\(task.points) P").bold(); Image(systemName: "camera.fill") }.padding(10).background(Color.btnBlue).foregroundColor(.white).cornerRadius(10)
            }.buttonStyle(PlainButtonStyle())
        }.padding().background(Color.white).cornerRadius(15).listRowSeparator(.hidden).listRowBackground(Color.clear)
    }

    func loadData() { loadTasks(); loadStats(); loadChampion(); loadEventInfo(); loadYearlyStats(); if user.role.lowercased() == "ebeveyn" { checkPending() } }
    func loadTasks() { guard let url = URL(string: "http://127.0.0.1:5000/tasks/\(user.id)") else { return }; URLSession.shared.dataTask(with: url) { d, _, _ in if let d = d, let dec = try? JSONDecoder().decode([TaskItem].self, from: d) { DispatchQueue.main.async { self.tasks = dec } } }.resume() }
    func loadStats() { guard let url = URL(string: "http://127.0.0.1:5000/stats/\(familyId)") else { return }; URLSession.shared.dataTask(with: url) { d, _, _ in if let d = d, let dec = try? JSONDecoder().decode([MemberStat].self, from: d) { DispatchQueue.main.async { self.stats = dec } } }.resume() }
    func loadChampion() { guard let url = URL(string: "http://127.0.0.1:5000/weekly_champion/\(familyId)") else { return }; URLSession.shared.dataTask(with: url) { d, _, _ in if let d = d, let dec = try? JSONDecoder().decode(Champion.self, from: d) { DispatchQueue.main.async { self.champion = dec } } }.resume() }
    func loadYearlyStats() { guard let url = URL(string: "http://127.0.0.1:5000/family_yearly_stats/\(familyId)") else { return }; URLSession.shared.dataTask(with: url) { d, _, _ in if let d = d, let json = try? JSONSerialization.jsonObject(with: d) as? [String: [String: Any]] { DispatchQueue.main.async { self.yearlyStats = json } } }.resume() }
    func loadEventInfo() { guard let url = URL(string: "http://127.0.0.1:5000/family_info/\(familyId)") else { return }; URLSession.shared.dataTask(with: url) { d, _, _ in if let d = d, let json = try? JSONSerialization.jsonObject(with: d) as? [String: Any] { DispatchQueue.main.async { self.weeklyMainEvent = json["weekly_main_event"] as? String ?? "Film Gecesi 🎬"; self.eventDetail = json["event_detail"] as? String ?? "Karar bekleniyor..." } } }.resume() }
    func checkPending() { guard let url = URL(string: "http://127.0.0.1:5000/pending_tasks/\(familyId)") else { return }; URLSession.shared.dataTask(with: url) { d, _, _ in if let d = d, let dec = try? JSONDecoder().decode([PendingTask].self, from: d) { DispatchQueue.main.async { self.pendingCount = dec.count } } }.resume() }
    
    func uploadProof() {
        guard let uiImage = inputImage, let task = selectedTask, let url = URL(string: "http://127.0.0.1:5000/complete_task") else { return }
        let boundary = "Boundary-\(UUID().uuidString)"
        var r = URLRequest(url: url); r.httpMethod = "POST"; r.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        let imageData = uiImage.jpegData(compressionQuality: 0.5)!
        var body = Data()
        let params = ["user_id": "\(user.id)", "task_id": "\(task.id)", "points": "\(task.points)"]
        for (k, v) in params { body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(k)\"\r\n\r\n\(v)\r\n".data(using: .utf8)!) }
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"image\"; filename=\"p.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData); body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        URLSession.shared.uploadTask(with: r, from: body) { _, _, _ in DispatchQueue.main.async { loadData() } }.resume()
    }
    
    func saveMainEventToDB(eventName: String) {
        let body: [String: Any] = ["family_id": familyId, "event_name": eventName]
        guard let url = URL(string: "http://127.0.0.1:5000/update_event") else { return }
        var r = URLRequest(url: url); r.httpMethod = "POST"; r.setValue("application/json", forHTTPHeaderField: "Content-Type"); r.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: r).resume()
    }
    
    func saveEventDetailToDB(detail: String) {
        let body: [String: Any] = ["family_id": familyId, "detail": detail]
        guard let url = URL(string: "http://127.0.0.1:5000/update_event_detail") else { return }
        var r = URLRequest(url: url); r.httpMethod = "POST"; r.setValue("application/json", forHTTPHeaderField: "Content-Type"); r.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: r).resume()
    }
}

// MARK: - 5. ALT GÖRÜNÜMLER
struct ActivityDetailView: View {
    let user: FamilyMember; let familyId: Int
    @Binding var mainEvent: String; @Binding var eventDetail: String
    var saveEvent: (String) -> Void; var saveDetail: (String) -> Void
    @State private var decisionMakerId: Int? = nil
    @State private var decisionMakerName: String = ""
    @State private var editingDetail: String = ""
    let options = ["Film Gecesi 🎬", "Piknik 🧺", "Dışarıda Yemek 🍕", "Oyun Gecesi 🎲"]

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 30) {
                    Text("Haftalık Plan").font(.largeTitle).bold().foregroundColor(.textMain)
                    if user.role.lowercased() == "ebeveyn" {
                        VStack(alignment: .leading) {
                            Text("Haftanın Etkinliğini Seç").font(.headline).padding(.leading)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(options, id: \.self) { opt in
                                        Button(action: { saveEvent(opt); mainEvent = opt; eventDetail = "Karar bekleniyor..." }) {
                                            Text(opt).padding().background(mainEvent == opt ? Color.titleColor : Color.white).foregroundColor(mainEvent == opt ? .white : .black).cornerRadius(15).shadow(radius: 2)
                                        }
                                    }
                                }.padding()
                            }
                        }
                    }
                    VStack(spacing: 20) {
                        Text("BU HAFTANIN PLANI").font(.caption).bold().foregroundColor(.secondary)
                        Text(mainEvent).font(.system(size: 34, weight: .black)).foregroundColor(.titleColor)
                        Image(systemName: "arrow.down.circle.fill").font(.title).foregroundColor(.secondary)
                        VStack {
                            Text("DETAY KARARI").font(.caption).bold().foregroundColor(.secondary)
                            Text(eventDetail).font(.title2).bold().multilineTextAlignment(.center).foregroundColor(.textMain)
                        }.padding().frame(maxWidth: .infinity).background(Color.appBg).cornerRadius(15)
                    }.padding(25).background(Color.white).cornerRadius(30).shadow(radius: 10).padding(.horizontal)

                    VStack(spacing: 15) {
                        if let dmId = decisionMakerId {
                            if dmId == user.id {
                                Text("🏆 Rozeti ilk sen kaptın! Detayı belirle:").bold().foregroundColor(.backBtn)
                                TextField("Örn: Hangi film? Nereye piknik?", text: $editingDetail).textFieldStyle(RoundedBorderTextFieldStyle()).padding(.horizontal)
                                Button("Kararı Onayla") { saveDetail(editingDetail); eventDetail = editingDetail }.padding().frame(maxWidth: .infinity).background(Color.backBtn).foregroundColor(.white).cornerRadius(12).bold().padding(.horizontal)
                            } else {
                                Text("💡 Karar Verici: \(decisionMakerName)").bold().foregroundColor(.textMain)
                                Text("Haftaya ilk rozeti sen al, kararı sen ver!").font(.caption).foregroundColor(.secondary)
                            }
                        } else {
                            Text("⏳ İlk rozet alan detayı seçecek...").italic().foregroundColor(.secondary)
                        }
                    }.padding().frame(maxWidth: .infinity).background(Color.white.opacity(0.8)).cornerRadius(20).padding(.horizontal)
                }
            }
        }.onAppear(perform: checkDecisionMaker)
    }
    func checkDecisionMaker() {
        guard let url = URL(string: "http://127.0.0.1:5000/family_decision_maker/\(familyId)") else { return }
        URLSession.shared.dataTask(with: url) { d, _, _ in
            if let d = d, let json = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
                DispatchQueue.main.async { self.decisionMakerId = json["user_id"] as? Int; self.decisionMakerName = json["isim"] as? String ?? "" }
            }
        }.resume()
    }
}

struct StatsDashboardView: View {
    let stats: [MemberStat]; let champion: Champion; let erdemScore: Int; let familyTotal: Int; let userCurrentScore: Int; let individualTarget: Int; let mainEvent: String; let eventDetail: String
    var body: some View {
        VStack(spacing: 0) {
            HStack { Text("Puan Durumu").font(.title2).bold().foregroundColor(.white); Spacer() }.padding().background(Color.titleColor)
            if familyTotal >= 1000 {
                VStack(spacing: 8) {
                    Text("🎉 AİLE HEDEFİ TAMAMLANDI!").bold().foregroundColor(.backBtn)
                    Text("\(mainEvent) Hazırlıkları Başlasın!").font(.subheadline).foregroundColor(.textMain)
                }.padding().frame(maxWidth: .infinity).background(Color.backBtn.opacity(0.15)).cornerRadius(12).padding()
            }
            HStack(spacing: 12) {
                ProgressCircleView(value: erdemScore, target: 500, title: "Erdem", color: .titleColor)
                ProgressCircleView(value: familyTotal, target: 1000, title: "Aile Hedefi", color: .btnBlue)
                ProgressCircleView(value: userCurrentScore, target: individualTarget, title: "Katkım", color: .backBtn)
            }.padding(.vertical, 30).frame(maxWidth: .infinity).background(Color.white).cornerRadius(20).shadow(radius: 5).padding()
            VStack(spacing: 12) {
                ForEach(stats) { s in
                    HStack { Text(s.isim).bold(); Spacer(); Text("\(s.total) P").bold().foregroundColor(.btnBlue) }.padding().background(Color.white).cornerRadius(12).shadow(radius: 2)
                }
            }.padding(.horizontal)
        }
    }
}

struct YearGridView: View {
    let familyStats: [String: [String: Any]]
    let columns = Array(repeating: GridItem(.fixed(20), spacing: 8), count: 13)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Yıllık Performans").font(.headline).foregroundColor(.textMain)
            
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(1...52, id: \.self) { week in
                    // UYARI VEREN SATIRI ŞU ŞEKİLDE DÜZELTTİK: ✨
                    let weekData = familyStats["\(week)"]
                    let score = weekData?["puan"] as? Int ?? 0
                    
                    RoundedRectangle(cornerRadius: 5)
                        .fill(score == 0 ? Color.gray.opacity(0.1) : Color.backBtn) // Puan varsa YEŞİL yanar ✅
                        .frame(width: 20, height: 20)
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(20)
            .shadow(radius: 5)
        }.padding()
    }
}

struct PointHistoryView: View {
    let userId: Int; @State private var logs: [PointLog] = []
    var body: some View {
        List(logs) { log in
            HStack {
                VStack(alignment: .leading) { Text(log.desc).bold(); Text(log.date).font(.caption) }
                Spacer(); Text("+\(log.amount)").foregroundColor(.blue).bold()
            }.padding().background(Color.white).cornerRadius(10).listRowSeparator(.hidden).listRowBackground(Color.clear)
        }.navigationTitle("Geçmiş").onAppear { guard let url = URL(string: "http://127.0.0.1:5000/point_history/\(userId)") else { return }; URLSession.shared.dataTask(with: url) { d, _, _ in if let d = d, let dec = try? JSONDecoder().decode([PointLog].self, from: d) { DispatchQueue.main.async { self.logs = dec } } }.resume() }
    }
}

struct BadgeGalleryView: View {
    let userId: Int; @State private var badges: [Badge] = []
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                ForEach(badges) { b in
                    VStack { Image(systemName: "seal.fill").font(.largeTitle).foregroundColor(.orange); Text(b.name).bold(); Text(b.date).font(.caption2) }.padding().frame(maxWidth: .infinity).background(Color.white).cornerRadius(20).shadow(radius: 5)
                }
            }.padding()
        }.navigationTitle("Rozetler").onAppear { guard let url = URL(string: "http://127.0.0.1:5000/user_badges/\(userId)") else { return }; URLSession.shared.dataTask(with: url) { d, _, _ in if let d = d, let dec = try? JSONDecoder().decode([Badge].self, from: d) { DispatchQueue.main.async { self.badges = dec } } }.resume() }
    }
}

// MARK: - 7. AUTH & PROFIL SEÇİMİ
struct AuthView: View {
    @Binding var familyId: Int?
    @State private var isRegister = false
    @State private var email = ""
    @State private var password = ""
    @State private var familyName = ""
    @State private var errorMessage = "" // Hata mesajlarını burada tutuyoruz

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()
            VStack(spacing: 25) {
                LottieView(name: "splash_animation").frame(width: 180, height: 180)
                
                Text(isRegister ? "Aileye Katıl" : "Hoş Geldiniz")
                    .font(.system(size: 34, weight: .black))
                    .foregroundColor(.textMain)
                
                VStack(spacing: 15) {
                    if isRegister {
                        TextField("Aile Adı (En az 3 karakter)", text: $familyName)
                            .padding().background(Color.white).cornerRadius(12)
                    }
                    
                    TextField("E-posta", text: $email)
                        .padding().background(Color.white).cornerRadius(12)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    
                    SecureField("Şifre (En az 6 karakter)", text: $password)
                        .padding().background(Color.white).cornerRadius(12)
                }.padding(.horizontal, 30)
                
                // HATA/UYARI MESAJI ALANI ✨
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.system(size: 14, weight: .bold))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        .transition(.opacity) // Mesajın yumuşak gelmesi için
                }

                Button(action: validateInputs) { // Doğrudan handleAuth yerine önce kontrole gidiyoruz
                    Text(isRegister ? "Kayıt Ol" : "Giriş Yap")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.btnBlue)
                        .foregroundColor(.white)
                        .cornerRadius(15)
                }.padding(.horizontal, 30)
                
                Button(isRegister ? "Zaten hesabım var" : "Yeni aile oluştur") {
                    withAnimation {
                        isRegister.toggle()
                        errorMessage = "" // Mod değişince eski hatayı temizle
                    }
                }.foregroundColor(.titleColor)
            }
        }
    }

    // 1. ADIM: GİRİŞ KRİTERLERİNİ KONTROL ET ✨
    func validateInputs() {
        errorMessage = "" // Önce temizle
        
        // E-posta kontrolü (Basit format kontrolü)
        if !email.contains("@") || !email.contains(".") {
            errorMessage = "Lütfen geçerli bir e-posta adresi giriniz."
            return
        }
        
        // Şifre uzunluğu kontrolü
        if password.count < 6 {
            errorMessage = "Şifreniz en az 6 karakter olmalıdır."
            return
        }
        
        // Kayıt modundaysa aile adı kontrolü
        if isRegister && familyName.trimmingCharacters(in: .whitespaces).count < 3 {
            errorMessage = "Aile adı en az 3 karakterden oluşmalıdır."
            return
        }
        
        // Her şey tamamsa backend'e gönder
        handleAuth()
    }

    // 2. ADIM: BACKEND İSTEĞİ
    func handleAuth() {
        let path = isRegister ? "register" : "login"
        let body: [String: Any] = isRegister ? ["family_name": familyName, "email": email, "password": password] : ["email": email, "password": password]
        
        guard let url = URL(string: "http://127.0.0.1:5000/\(path)") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: req) { d, res, err in
            if let err = err {
                DispatchQueue.main.async { self.errorMessage = "Sunucuya bağlanılamadı: \(err.localizedDescription)" }
                return
            }
            
            if let d = d {
                if let json = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
                    DispatchQueue.main.async {
                        // Backend'den başarılı ID dönerse giriş yap
                        if let fId = json["family_id"] as? Int {
                            self.familyId = fId
                        }
                        // Backend'den gelen spesifik hata mesajını göster (Örn: "Hatalı şifre")
                        else if let msg = json["message"] as? String {
                            self.errorMessage = msg
                        } else {
                            self.errorMessage = "Giriş başarısız. Lütfen bilgilerinizi kontrol edin."
                        }
                    }
                }
            }
        }.resume()
    }
}
struct ProfileSelectionView: View {
    let familyId: Int
    @Binding var selectedUser: FamilyMember?
    var onLogout: () -> Void
    
    @State private var members: [FamilyMember] = []
    @State private var showAddUser = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.appBg.ignoresSafeArea()
                
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                        ForEach(members) { m in
                            VStack(spacing: 12) {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .frame(width: 70, height: 70)
                                    .foregroundColor(m.role.lowercased() == "ebeveyn" ? .btnBlue : .backBtn)
                                
                                Text(m.isim).font(.headline)
                                Text(m.role).font(.caption).bold().foregroundColor(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
                            .cornerRadius(25)
                            .shadow(radius: 5)
                            .onTapGesture { selectedUser = m }
                            // KULLANICI ÜZERİNE BASILI TUTUNCA ÇIKAN MENÜ ✨
                            .contextMenu {
                                Button(role: .destructive) {
                                    deleteUser(id: m.id)
                                } label: {
                                    Label("Kullanıcıyı Sil", systemImage: "trash")
                                }
                            }
                        }
                    }.padding()
                }
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { showAddUser = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.titleColor)
                                .background(Color.white.clipShape(Circle()))
                        }.padding(30)
                    }
                }
            }
            .navigationTitle("Profil Seç")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Çıkış", action: onLogout).foregroundColor(.red).bold()
                }
            }
            .sheet(isPresented: $showAddUser) {
                AddUserView(familyId: familyId) { loadUsers() }
            }
            .onAppear(perform: loadUsers)
        }
    }
    
    // VERİLERİ YÜKLEME
    func loadUsers() {
        guard let url = URL(string: "http://127.0.0.1:5000/users/\(familyId)") else { return }
        URLSession.shared.dataTask(with: url) { d, _, _ in
            if let d = d, let dec = try? JSONDecoder().decode([FamilyMember].self, from: d) {
                DispatchQueue.main.async { self.members = dec }
            }
        }.resume()
    }
    
    // KULLANICI SİLME FONKSİYONU ✨
    func deleteUser(id: Int) {
        guard let url = URL(string: "http://127.0.0.1:5000/delete_user/\(id)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        URLSession.shared.dataTask(with: request) { _, response, _ in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                DispatchQueue.main.async {
                    loadUsers() // Silme başarılıysa listeyi yenile
                }
            }
        }.resume()
    }
}

struct AddUserView: View {
    let familyId: Int; var onComplete: () -> Void; @Environment(\.dismiss) var dismiss
    @State private var name = ""; @State private var selectedRoleId = 2
    var body: some View {
        NavigationView {
            Form {
                Section { TextField("İsim", text: $name); Picker("Rol", selection: $selectedRoleId) { Text("Ebeveyn").tag(1); Text("Çocuk").tag(2) }.pickerStyle(SegmentedPickerStyle()) }
                Button("Ekle") {
                    let b: [String: Any] = ["family_id": familyId, "role_id": selectedRoleId, "isim": name]
                    guard let url = URL(string: "http://127.0.0.1:5000/add_user") else { return }
                    var r = URLRequest(url: url); r.httpMethod = "POST"; r.setValue("application/json", forHTTPHeaderField: "Content-Type"); r.httpBody = try? JSONSerialization.data(withJSONObject: b)
                    URLSession.shared.dataTask(with: r) { _, _, _ in DispatchQueue.main.async { onComplete(); dismiss() } }.resume()
                }.bold().frame(maxWidth: .infinity).foregroundColor(.backBtn)
            }.navigationTitle("Yeni Profil")
        }
    }
}

// MARK: - 8. EKSİK OLAN GÖRÜNÜMLER (HATALARI GİDEREN KISIM)
struct AddTaskView: View {
    let familyId: Int; var onComp: () -> Void; @Environment(\.dismiss) var dismiss
    @State private var members: [FamilyMember] = []; @State private var title = ""; @State private var targetId = 0; @State private var points = "10"; @State private var isErdem = false
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("GÖREV BİLGİLERİ")) {
                    TextField("Görev Adı", text: $title); TextField("Puan", text: $points).keyboardType(.numberPad)
                    Picker("Kime Atansın?", selection: $targetId) { ForEach(members) { m in Text(m.isim).tag(m.id) } }
                }
                Section(header: Text("ERDEM DURUMU")) {
                    Toggle(isOn: $isErdem) { HStack { Image(systemName: "heart.fill").foregroundColor(.titleColor); Text("Bu bir Erdem Görevi mi?") } }
                }
                Button("Görev Oluştur") {
                    let body: [String: Any] = ["title": title, "points": Int(points) ?? 10, "assigned_to": targetId, "is_erdem": isErdem]
                    guard let url = URL(string: "http://127.0.0.1:5000/add_task") else { return }
                    var r = URLRequest(url: url); r.httpMethod = "POST"; r.setValue("application/json", forHTTPHeaderField: "Content-Type"); r.httpBody = try? JSONSerialization.data(withJSONObject: body)
                    URLSession.shared.dataTask(with: r) { _, _, _ in DispatchQueue.main.async { onComp(); dismiss() } }.resume()
                }.bold().frame(maxWidth: .infinity).foregroundColor(.btnBlue)
            }.navigationTitle("Yeni Görev").onAppear {
                guard let url = URL(string: "http://127.0.0.1:5000/users/\(familyId)") else { return }
                URLSession.shared.dataTask(with: url) { d, _, _ in if let d = d, let dec = try? JSONDecoder().decode([FamilyMember].self, from: d) { DispatchQueue.main.async { self.members = dec; self.targetId = dec.first?.id ?? 0 } } }.resume()
            }
        }
    }
}

struct ApprovalRoomView: View {
    let familyId: Int; var onComplete: () -> Void; @State private var pending: [PendingTask] = []; @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationView {
            ZStack {
                Color.appBg.ignoresSafeArea()
                if pending.isEmpty { Text("Bekleyen görev yok. 🎉").foregroundColor(.secondary) }
                else {
                    List(pending) { task in
                        VStack(alignment: .leading, spacing: 15) {
                            HStack { VStack(alignment: .leading) { Text(task.user_name).font(.headline); Text(task.task_title).font(.subheadline).foregroundColor(.secondary) }; Spacer(); Text("\(task.points) P").bold().foregroundColor(.titleColor) }
                            if let img = task.image { AsyncImage(url: URL(string: "http://127.0.0.1:5000/uploads/\(img)")) { i in i.resizable().aspectRatio(contentMode: .fill) } placeholder: { ProgressView() }.frame(height: 180).cornerRadius(12).clipped() }
                            HStack(spacing: 20) {
                                Button(action: { reject(id: task.id) }) { Label("Reddet", systemImage: "xmark.circle.fill").frame(maxWidth: .infinity).padding().background(Color.red.opacity(0.8)).foregroundColor(.white).cornerRadius(12) }
                                Button(action: { approve(id: task.id) }) { Label("Onayla", systemImage: "checkmark.circle.fill").frame(maxWidth: .infinity).padding().background(Color.backBtn).foregroundColor(.white).cornerRadius(12) }
                            }
                        }.padding().background(Color.white).cornerRadius(20).listRowSeparator(.hidden).listRowBackground(Color.clear)
                    }.listStyle(PlainListStyle())
                }
            }.navigationTitle("Onay Bekleyenler").onAppear(perform: load).toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Kapat") { dismiss() } } }
        }
    }
    func load() { guard let url = URL(string: "http://127.0.0.1:5000/pending_tasks/\(familyId)") else { return }; URLSession.shared.dataTask(with: url) { d, _, _ in if let d = d, let dec = try? JSONDecoder().decode([PendingTask].self, from: d) { DispatchQueue.main.async { self.pending = dec } } }.resume() }
    func approve(id: Int) {
        guard let url = URL(string: "http://127.0.0.1:5000/approve_task/\(id)") else { return }
        var r = URLRequest(url: url); r.httpMethod = "POST"
        URLSession.shared.dataTask(with: r) { _, res, _ in if let httpRes = res as? HTTPURLResponse, httpRes.statusCode == 200 { DispatchQueue.main.async { load(); onComplete() } } }.resume()
    }
    func reject(id: Int) { guard let url = URL(string: "http://127.0.0.1:5000/reject_task/\(id)") else { return }; var r = URLRequest(url: url); r.httpMethod = "POST"; URLSession.shared.dataTask(with: r) { _, _, _ in DispatchQueue.main.async { load(); onComplete() } }.resume() }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?; @Environment(\.dismiss) var dismiss
    func makeUIViewController(context: Context) -> UIImagePickerController { let picker = UIImagePickerController(); picker.delegate = context.coordinator; return picker }
    func updateUIViewController(_ ui: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker; init(_ p: ImagePicker) { parent = p }
        func imagePickerController(_ p: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) { parent.image = info[.originalImage] as? UIImage; parent.dismiss() }
    }
}

#Preview { ContentView() }
