import SwiftUI

struct AppEntryView: View {
    @EnvironmentObject private var authentication: AuthenticationStore

    var body: some View {
        Group {
            if authentication.isLoginPresented {
                LoginView()
                    .transition(.opacity)
            } else {
                RootView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: authentication.isLoginPresented)
        .task {
            await authentication.validateStoredSession()
        }
    }
}

struct LoginView: View {
    @EnvironmentObject private var authentication: AuthenticationStore
    @State private var legalDocument: LegalDocument?

    var body: some View {
        ZStack {
            HuJuTheme.paper
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 40) {
                    brand
                    signInActions
                }
                .padding(.bottom, 92)
            }
            .safeAreaInset(edge: .bottom) {
                legalFooter
                    .padding(.top, 12)
                    .background(HuJuTheme.paper)
            }

            if authentication.isWorking {
                Color.black.opacity(0.16)
                    .ignoresSafeArea()
                ProgressView("正在登录")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 20)
                    .frame(height: 52)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .alert(
            "登录未完成",
            isPresented: Binding(
                get: { authentication.errorMessage != nil },
                set: { if !$0 { authentication.errorMessage = nil } }
            )
        ) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(authentication.errorMessage ?? "")
        }
        .sheet(item: $legalDocument) { document in
            LegalDocumentView(document: document)
        }
    }

    private var brand: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Image(systemName: "house.and.flag.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(HuJuTheme.green)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Spacer()
                Text("上海")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HuJuTheme.green)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(HuJuTheme.green.opacity(0.09))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("沪居")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(HuJuTheme.ink)
                Text("把看过的房子，慢慢整理成自己的答案。")
                    .font(.subheadline)
                    .foregroundStyle(HuJuTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 44)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var signInActions: some View {
        VStack(spacing: 14) {
            Button {
                authentication.continueWithoutAccount()
            } label: {
                Label("直接开始", systemImage: "house.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(HuJuTheme.green)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(authentication.isWorking)

            Button {
                authentication.signInWithApple()
            } label: {
                Label("通过苹果登录", systemImage: "apple.logo")
                    .font(.headline)
                    .foregroundStyle(HuJuTheme.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(HuJuTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(HuJuTheme.line)
                    }
            }
            .disabled(authentication.isWorking)

            Text("无需账号，预算与看房记录默认只保存在本机")
                .font(.caption)
                .foregroundStyle(HuJuTheme.muted)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
    }

    private var legalFooter: some View {
        HStack(spacing: 4) {
            Text("继续使用即表示你同意")
                .foregroundStyle(HuJuTheme.muted)
            Button("服务条款") {
                legalDocument = .terms
            }
            Text("和")
                .foregroundStyle(HuJuTheme.muted)
            Button("隐私政策") {
                legalDocument = .privacy
            }
        }
        .font(.caption)
        .buttonStyle(.plain)
        .foregroundStyle(HuJuTheme.green)
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 24)
        .padding(.bottom, 10)
    }
}

private enum LegalDocument: String, Identifiable {
    case terms
    case privacy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .terms: "服务条款"
        case .privacy: "隐私政策"
        }
    }

    var sections: [(title: String, detail: String)] {
        switch self {
        case .terms:
            [
                (
                    "使用范围",
                    "沪居用于整理个人看房记录与购房决策证据，不提供官方估价、贷款、税务、产权或学区结论。"
                ),
                (
                    "信息核验",
                    "房源、市场与政策信息可能发生变化。作出交易决定前，请通过政府部门、金融机构和专业服务人员核验。"
                ),
                (
                    "本机与可选登录",
                    "无需注册即可使用全部本地功能。使用苹果账号登录不会把预算、地址或看房记录上传到开发者服务器。"
                )
            ]
        case .privacy:
            [
                (
                    "本地优先",
                    "预算、房源、看房笔记和现场附件默认保存在本机，不会因登录自动上传。"
                ),
                (
                    "登录信息",
                    "沪居只保存稳定用户标识、显示名称和登录方式；登录状态存放在系统钥匙串中。"
                ),
                (
                    "第三方服务",
                    "可选的苹果登录由系统处理。未获得你的明确授权前，沪居不会把地址、收入或看房笔记发送给远端服务。"
                )
            ]
        }
    }
}

private struct LegalDocumentView: View {
    @Environment(\.dismiss) private var dismiss
    let document: LegalDocument

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("更新日期：2026 年 9 月 6 日")
                        .font(.caption)
                        .foregroundStyle(HuJuTheme.muted)
                }

                ForEach(Array(document.sections.enumerated()), id: \.offset) { _, section in
                    Section(section.title) {
                        Text(section.detail)
                            .font(.body)
                            .foregroundStyle(HuJuTheme.ink)
                    }
                }
            }
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct AccountView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authentication: AuthenticationStore
    @EnvironmentObject private var store: PropertyStore
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 42))
                            .foregroundStyle(HuJuTheme.green)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(authentication.currentUser?.displayName ?? "本机模式")
                                .font(.headline)
                            Text(accountSubtitle)
                                .font(.caption)
                                .foregroundStyle(HuJuTheme.muted)
                        }
                    }
                    .padding(.vertical, 5)
                }

                Section("隐私") {
                    Label("看房记录默认只保存在本机", systemImage: "iphone")
                    Label("不含广告或跨应用跟踪", systemImage: "hand.raised.fill")
                }

                Section {
                    if authentication.isAuthenticated {
                        Button("退出可选登录") {
                            if authentication.signOut() {
                                dismiss()
                            }
                        }
                    } else {
                        Button {
                            authentication.presentLogin()
                            dismiss()
                        } label: {
                            Label("使用苹果账号登录", systemImage: "apple.logo")
                        }
                    }
                }

                Section {
                    Button("清除本机全部数据", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                } footer: {
                    Text("将删除预算、房源、看房证据、照片视频和本机登录状态，此操作无法撤销。")
                }
            }
            .navigationTitle("个人与隐私")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .alert(
                "退出未完成",
                isPresented: Binding(
                    get: { authentication.errorMessage != nil },
                    set: { if !$0 { authentication.errorMessage = nil } }
                )
            ) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(authentication.errorMessage ?? "")
            }
            .confirmationDialog(
                "确认清除本机全部数据？",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("清除全部数据", role: .destructive) {
                    store.deleteAllUserData()
                    if authentication.signOut() {
                        dismiss()
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("预算、房源、看房证据和本机影像将永久删除。")
            }
        }
    }

    private var accountSubtitle: String {
        guard let user = authentication.currentUser else {
            return "无需账号，数据不离开设备"
        }
        return "通过\(user.provider.title)登录，业务数据仍保存在本机"
    }
}
