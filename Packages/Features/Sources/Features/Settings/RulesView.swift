import DesignSystem
import Domain
import SwiftUI

/// F1 — "İçe aktarma kuralları · 7 kural · 2 banka şablonu".
public struct RulesView: View {
    let environment: AppEnvironment

    @State private var rules: [CategoryRuleEntity] = []
    @State private var profiles: [ParserProfileEntity] = []
    @State private var categories = CategoryLookup()

    public var body: some View {
        List {
            Section("Kategori kuralları") {
                if rules.isEmpty {
                    Text("Kural yok").font(.sd.meta).foregroundStyle(Color.text.muted)
                }
                ForEach(rules) { rule in
                    VStack(alignment: .leading, spacing: 1) {
                        Text("“\(rule.keyword)” içeren satırlar")
                            .font(.sd.bodyItem)
                            .foregroundStyle(Color.text.primary)
                        Text(categories.name(rule.categoryID)
                             + (rule.isUserDefined ? " · kendi kuralınız" : " · varsayılan"))
                            .font(.sd.meta)
                            .foregroundStyle(Color.text.muted)
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Sil", role: .destructive) {
                            Task {
                                try? await environment.categoryRules.delete(id: rule.id)
                                await load()
                            }
                        }
                    }
                }
            }

            Section("Banka şablonları") {
                if profiles.isEmpty {
                    Text("Şablon yok").font(.sd.meta).foregroundStyle(Color.text.muted)
                }
                ForEach(profiles) { profile in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(profile.bankName)
                            .font(.sd.bodyItem)
                            .foregroundStyle(Color.text.primary)
                        Text(profile.formatIdentifier)
                            .font(.sd.meta)
                            .foregroundStyle(Color.text.muted)
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Sil", role: .destructive) {
                            Task {
                                try? await environment.parserProfiles?.delete(id: profile.id)
                                await load()
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("İçe aktarma kuralları")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        rules = (try? await environment.categoryRules.all()) ?? []
        profiles = (try? await environment.parserProfiles?.all()) ?? []
        categories = CategoryLookup(
            (try? await environment.categories.all(includeArchived: true)) ?? [])
    }
}

extension CategoryRuleEntity: @retroactive Identifiable {}
extension ParserProfileEntity: @retroactive Identifiable {}
