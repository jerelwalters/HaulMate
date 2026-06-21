//
//  Created by Jerel Walters on 6/20/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import Foundation
import SwiftUI

enum DashboardContentState: Equatable {
    case empty
    case loaded(DashboardSnapshot)
}

struct DashboardSnapshot: Equatable {
    struct AttentionItem: Equatable, Identifiable {
        enum Kind: Equatable {
            case document
            case overdue
        }

        let id: UUID
        let kind: Kind
        let title: String
        let detail: String?
    }

    let loadID: UUID
    let reference: String
    let route: String
    let status: String
    let deliveryAppointment: Date
    let appointmentTimeZone: TimeZone
    let acceptedPay: Decimal
    let estimatedProfit: Decimal
    let profitPerTotalMile: Decimal
    let attentionItems: [AttentionItem]
}

struct DashboardTabView: View {
    @Environment(\.appDependencies) private var dependencies

    let user: SessionUser
    let state: DashboardContentState

    private var router: AppRouter { dependencies.required.router }

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.dashboardPath) {
            ZStack {
                HMColor.canvas
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: HMSpacing.lg) {
                        header

                        switch state {
                        case .empty:
                            emptyContent
                        case .loaded(let snapshot):
                            syncStatus
                            loadedContent(snapshot)
                        }
                    }
                    .padding(.horizontal, HMSpacing.lg)
                    .padding(.bottom, HMSpacing.xxl)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: DashboardRoute.self) { route in
                switch route {
                case .activeLoad(let id):
                    LoadDetailView(loadID: id)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: HMSpacing.xl) {
            HStack {
                Text("HaulMate")
                    .font(.title3.bold().italic())
                    .foregroundStyle(HMColor.textPrimary)

                Spacer()

                Button(action: showNewLoad) {
                    Image(systemName: "plus")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(HMColor.brandNavy, in: Circle())
                }
                .accessibilityLabel("New Load")
                .accessibilityIdentifier("dashboard.new-load")
            }

            VStack(alignment: .leading, spacing: HMSpacing.xs) {
                Text("Today")
                    .font(HMFont.screenTitle)
                    .foregroundStyle(HMColor.textPrimary)
                Text("Ready when you are, \(user.displayName).")
                    .font(HMFont.body)
                    .foregroundStyle(HMColor.textSecondary)
            }
        }
        .padding(.top, HMSpacing.md)
    }

    private var syncStatus: some View {
        Label("Updated just now · synced", systemImage: "checkmark.circle")
            .font(HMFont.caption)
            .foregroundStyle(HMColor.success)
    }

    private var emptyContent: some View {
        VStack(alignment: .leading, spacing: HMSpacing.lg) {
            Image(systemName: "truck.box")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(HMColor.accent)

            VStack(alignment: .leading, spacing: HMSpacing.sm) {
                Text("No active load")
                    .font(HMFont.sectionTitle)
                    .foregroundStyle(HMColor.textPrimary)
                Text("Create a load when you're ready to evaluate your next run.")
                    .font(HMFont.body)
                    .foregroundStyle(HMColor.textSecondary)
            }

            Button("Create a load", action: showNewLoad)
                .buttonStyle(HMPrimaryButtonStyle(kind: .accent))
                .accessibilityIdentifier("dashboard.empty.new-load")
        }
        .padding(HMSpacing.xl)
        .hmCard()
    }

    @ViewBuilder
    private func loadedContent(_ snapshot: DashboardSnapshot) -> some View {
        activeLoadCard(snapshot)
        profitCard(snapshot)

        if !snapshot.attentionItems.isEmpty {
            VStack(alignment: .leading, spacing: HMSpacing.md) {
                Text("Needs attention")
                    .font(HMFont.sectionTitle)
                    .foregroundStyle(HMColor.textPrimary)

                VStack(spacing: 0) {
                    ForEach(Array(snapshot.attentionItems.enumerated()), id: \.element.id) { index, item in
                        attentionRow(item)

                        if index < snapshot.attentionItems.count - 1 {
                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }
                .hmCard()
            }
        }
    }

    private func activeLoadCard(_ snapshot: DashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: HMSpacing.lg) {
            Text("ACTIVE LOAD")
                .font(HMFont.eyebrow)
                .foregroundStyle(.white.opacity(0.68))

            VStack(alignment: .leading, spacing: HMSpacing.xs) {
                Text(snapshot.reference)
                    .font(.system(.largeTitle, design: .default, weight: .heavy))
                Text(snapshot.route)
                    .font(HMFont.cardTitle)
            }
            .foregroundStyle(.white)

            Text(snapshot.status.uppercased())
                .font(HMFont.eyebrow)
                .foregroundStyle(HMColor.success)
                .padding(.horizontal, HMSpacing.md)
                .padding(.vertical, HMSpacing.sm)
                .background(HMColor.successSurface, in: RoundedRectangle(cornerRadius: HMRadius.small))

            HStack(spacing: HMSpacing.lg) {
                metric(
                    label: "DELIVERY APPOINTMENT",
                    value: appointmentText(snapshot)
                )
                Divider()
                    .overlay(.white.opacity(0.25))
                metric(
                    label: "ACCEPTED PAY",
                    value: currency(snapshot.acceptedPay, fractionDigits: 0)
                )
            }
            .fixedSize(horizontal: false, vertical: true)

            Button("Open active load") {
                router.dashboardPath.append(.activeLoad(id: snapshot.loadID))
            }
            .buttonStyle(HMPrimaryButtonStyle(kind: .accent))
            .accessibilityIdentifier("dashboard.active-load.open")
        }
        .padding(HMSpacing.xl)
        .background(HMColor.brandNavy, in: RoundedRectangle(cornerRadius: HMRadius.large))
    }

    private func profitCard(_ snapshot: DashboardSnapshot) -> some View {
        HStack(spacing: HMSpacing.lg) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.title2.weight(.bold))
                .foregroundStyle(HMColor.success)
                .frame(width: 44, height: 44)
                .background(HMColor.successSurface, in: RoundedRectangle(cornerRadius: HMRadius.medium))

            VStack(alignment: .leading, spacing: HMSpacing.xs) {
                Text("EST. PROFIT")
                    .font(HMFont.eyebrow)
                    .foregroundStyle(HMColor.textSecondary)
                Text(currency(snapshot.estimatedProfit, fractionDigits: 0))
                    .font(HMFont.sectionTitle)
                    .foregroundStyle(HMColor.success)
            }

            Spacer()

            Text("\(currency(snapshot.profitPerTotalMile, fractionDigits: 2)) / total mi")
                .font(HMFont.cardTitle)
                .foregroundStyle(HMColor.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(HMSpacing.lg)
        .hmCard()
    }

    private func attentionRow(_ item: DashboardSnapshot.AttentionItem) -> some View {
        HStack(spacing: HMSpacing.md) {
            Image(systemName: item.kind == .document ? "doc.text" : "exclamationmark")
                .font(.headline.weight(.bold))
                .foregroundStyle(item.kind == .document ? HMColor.warning : HMColor.danger)
                .frame(width: 36, height: 36)
                .background(
                    item.kind == .document ? HMColor.warningSurface : HMColor.dangerSurface,
                    in: Circle()
                )

            VStack(alignment: .leading, spacing: HMSpacing.xs) {
                Text(item.title)
                    .font(HMFont.cardTitle)
                    .foregroundStyle(HMColor.textPrimary)
                if let detail = item.detail {
                    Text(detail)
                        .font(HMFont.caption)
                        .foregroundStyle(HMColor.textSecondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(HMColor.textSecondary)
        }
        .padding(HMSpacing.lg)
    }

    private func metric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: HMSpacing.xs) {
            Text(label)
                .font(HMFont.eyebrow)
                .foregroundStyle(.white.opacity(0.68))
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .minimumScaleFactor(0.75)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func appointmentText(_ snapshot: DashboardSnapshot) -> String {
        var format = Date.FormatStyle(date: .omitted, time: .shortened)
        format.timeZone = snapshot.appointmentTimeZone
        return snapshot.deliveryAppointment.formatted(format)
    }

    private func currency(_ amount: Decimal, fractionDigits: Int) -> String {
        amount.formatted(
            .currency(code: "USD")
            .precision(.fractionLength(fractionDigits))
        )
    }

    private func showNewLoad() {
        router.presentedSheet = .newLoad
    }
}

#if DEBUG
#Preview("Empty") {
    DashboardTabView(user: .preview, state: .empty)
        .withPreviewDependencies(user: .preview)
}

#Preview("Active Load") {
    DashboardTabView(user: .preview, state: .loaded(.preview))
        .withPreviewDependencies(user: .preview)
}

private extension DashboardSnapshot {
    static let preview = DashboardSnapshot(
        loadID: UUID(uuidString: "C4E19E8A-6CA4-40D8-8B76-4ECA8C892DB3")!,
        reference: "HM-1048",
        route: "Detroit, MI  →  Columbus, OH",
        status: "In transit",
        deliveryAppointment: Date(timeIntervalSince1970: 1_782_052_200),
        appointmentTimeZone: TimeZone(identifier: "America/New_York")!,
        acceptedPay: Decimal(1_850),
        estimatedProfit: Decimal(612),
        profitPerTotalMile: Decimal(string: "1.00")!,
        attentionItems: [
            AttentionItem(
                id: UUID(uuidString: "609952DA-C8D0-4A97-96E6-5E24BDBF15FA")!,
                kind: .document,
                title: "POD required after delivery",
                detail: nil
            ),
            AttentionItem(
                id: UUID(uuidString: "757F9044-FC02-4CF0-84B5-9372B73980E1")!,
                kind: .overdue,
                title: "Invoice HM-1042",
                detail: "Overdue · 4 days · $985 remaining"
            )
        ]
    )
}
#endif
