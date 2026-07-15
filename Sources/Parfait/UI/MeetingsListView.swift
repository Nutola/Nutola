import SwiftUI

struct MeetingsListView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.colorScheme) private var scheme
    @Environment(\.parfaitActionColor) private var actionColor

    private var groups: [MeetingDayGroup] {
        MeetingDayGrouper.group(meetings: app.store.meetings)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Meetings")
                    .font(.parfait(22, .bold))
                    .foregroundStyle(Theme.heading(scheme))

                if groups.isEmpty {
                    EmptyStateView(
                        title: "No meetings yet",
                        message: "Recorded meetings will appear here.")
                } else {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(groups) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Text(group.label)
                                        .font(.parfait(15, .semibold))
                                        .foregroundStyle(Theme.sectionTitle(scheme, accent: actionColor))
                                    Text("\(group.meetings.count)")
                                        .font(.parfait(11, .medium))
                                        .foregroundStyle(Theme.tertiary(scheme))
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 2)
                                        .background(Theme.chip(scheme), in: Capsule())
                                }
                                VStack(spacing: 0) {
                                    ForEach(group.meetings) { meeting in
                                        MeetingHistoryRow(meeting: meeting) {
                                            app.openMeetingID = meeting.id
                                        }
                                        if meeting.id != group.meetings.last?.id {
                                            Divider().padding(.leading, 8)
                                        }
                                    }
                                }
                                .cardStyle()
                            }
                        }
                    }
                }
            }
            .padding(24)
            .contentColumn()
        }
        .background(Theme.surface(scheme))
    }
}
