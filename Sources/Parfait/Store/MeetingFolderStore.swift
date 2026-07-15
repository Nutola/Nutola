import Foundation
import SwiftUI

@MainActor
final class MeetingFolderStore: ObservableObject {
    let archive: FolderArchive
    @Published private(set) var folders: [MeetingFolder] = []
    @Published private(set) var titleRules: [FolderTitleRule] = []

    init(archive: FolderArchive = FolderArchive()) {
        self.archive = archive
        reload()
    }

    func reload() {
        folders = archive.allFolders()
        titleRules = archive.allTitleRules()
    }

    @discardableResult
    func createFolder(
        name: String,
        description: String? = nil,
        iconKind: FolderIconKind = .symbol,
        iconValue: String = "folder.fill",
        iconColorHex: String = "#3FB27F"
    ) -> MeetingFolder {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDesc = description?.trimmingCharacters(in: .whitespacesAndNewlines)
        let folder = MeetingFolder(
            name: trimmed.isEmpty ? "New folder" : trimmed,
            description: (trimmedDesc?.isEmpty == false) ? trimmedDesc : nil,
            createdAt: Date(),
            sortOrder: (folders.map(\.sortOrder).max() ?? -1) + 1,
            iconKind: iconKind,
            iconValue: iconValue,
            iconColorHex: iconColorHex)
        try? archive.save(folder)
        reload()
        return folder
    }

    func updateFolder(_ folder: MeetingFolder) {
        try? archive.save(folder)
        reload()
    }

    func deleteFolder(id: UUID, meetingStore: MeetingStore) {
        for meeting in meetingStore.meetings where meeting.folderID == id {
            var m = meeting
            m.folderID = nil
            meetingStore.upsert(m)
        }
        try? archive.deleteFolder(id: id)
        reload()
    }

    func assign(meetingID: UUID, to folderID: UUID?, meetingStore: MeetingStore) {
        guard var meeting = meetingStore.meeting(id: meetingID) else { return }
        meeting.folderID = folderID
        meetingStore.upsert(meeting)
        if let folderID {
            setRuleAndBackfill(for: meeting, folderID: folderID, meetingStore: meetingStore)
        }
    }

    func assign(calendarTitle: String, to folderID: UUID, meetingStore: MeetingStore) {
        let key = FolderTitleNormalizer.key(for: calendarTitle)
        guard !key.isEmpty else { return }
        try? archive.setRule(normalizedTitle: key, folderID: folderID)
        reload()
        backfillUnfiled(forKey: key, folderID: folderID, meetingStore: meetingStore)
    }

    func folder(forTitle title: String) -> MeetingFolder? {
        guard let rule = archive.rule(forTitle: title) else { return nil }
        return folders.first { $0.id == rule.folderID }
    }

    func folder(id: UUID) -> MeetingFolder? {
        folders.first { $0.id == id }
    }

    func meetings(in folderID: UUID, from store: MeetingStore) -> [Meeting] {
        store.meetings
            .filter { $0.folderID == folderID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Private

    private func setRuleAndBackfill(
        for meeting: Meeting, folderID: UUID, meetingStore: MeetingStore
    ) {
        let raw = meeting.calendarEventTitle ?? meeting.title
        let key = FolderTitleNormalizer.key(for: raw)
        guard !key.isEmpty else { return }
        try? archive.setRule(normalizedTitle: key, folderID: folderID)
        reload()
        backfillUnfiled(forKey: key, folderID: folderID, meetingStore: meetingStore)
    }

    private func backfillUnfiled(
        forKey key: String, folderID: UUID, meetingStore: MeetingStore
    ) {
        for meeting in meetingStore.meetings where meeting.folderID == nil {
            let raw = meeting.calendarEventTitle ?? meeting.title
            guard FolderTitleNormalizer.key(for: raw) == key else { continue }
            var m = meeting
            m.folderID = folderID
            meetingStore.upsert(m)
        }
    }
}
