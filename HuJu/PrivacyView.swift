import SwiftUI

struct AccountView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PropertyStore
    @State private var showDeleteConfirmation = false
    @State private var legalDocument: LegalDocument?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "iphone.circle.fill")
                            .font(.system(size: 42))
                            .foregroundStyle(HuJuTheme.green)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("本机模式")
                                .font(.headline)
                            Text("无需账号，数据不离开设备")
                                .font(.caption)
                                .foregroundStyle(HuJuTheme.muted)
                        }
                    }
                    .padding(.vertical, 5)
                }

                Section("隐私") {
                    Label("看房记录默认只保存在本机", systemImage: "internaldrive")
                    Label("不含广告或跨应用跟踪", systemImage: "hand.raised.fill")
                }

                Section("法律") {
                    Button {
                        legalDocument = .terms
                    } label: {
                        HStack {
                            Label("服务条款", systemImage: "doc.text")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(HuJuTheme.muted)
                        }
                    }
                    Button {
                        legalDocument = .privacy
                    } label: {
                        HStack {
                            Label("隐私政策", systemImage: "lock.shield")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(HuJuTheme.muted)
                        }
                    }
                }

                Section {
                    Button("清除本机全部数据", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                } footer: {
                    Text("将删除预算、房源、看房证据、照片和视频，此操作无法撤销。")
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
            .sheet(item: $legalDocument) { document in
                LegalDocumentView(document: document)
            }
            .confirmationDialog(
                "确认清除本机全部数据？",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("清除全部数据", role: .destructive) {
                    store.deleteAllUserData()
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("预算、房源、看房证据和本机影像将永久删除。")
            }
        }
    }
}

enum LegalDocument: String, Identifiable {
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
                    "选个家用于整理个人看房记录与购房决策证据，不提供官方估价、贷款、税务、产权或学区结论。"
                ),
                (
                    "信息核验",
                    "房源、市场与政策信息可能发生变化。作出交易决定前，请通过政府部门、金融机构和专业服务人员核验。"
                ),
                (
                    "系统地图",
                    "保存房源时可能使用 Apple MapKit 解析地图坐标。地图结果仅用于记录与展示，不代表官方地址、产权边界或交易信息。"
                ),
                (
                    "本机数据",
                    "无需注册或登录即可使用全部功能。预算、地址和看房记录只保存在本机，不会上传到开发者服务器。"
                )
            ]
        case .privacy:
            [
                (
                    "本地优先",
                    "预算、房源、看房笔记和现场附件默认保存在本机，不会上传到开发者服务器。"
                ),
                (
                    "第三方服务",
                    "地图由 Apple MapKit 系统服务处理。保存房源时，城市、行政区、板块和小区名称可能由 MapKit 用于解析地图坐标；开发者不会收到这些查询，也不会把收入、笔记或现场附件发送给远端服务。"
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
                    Text("更新日期：2026 年 9 月 7 日")
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
