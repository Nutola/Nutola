import AppKit
import SwiftUI

struct MeetingDetailView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.colorScheme) private var scheme

    @State private var meeting: Meeting
    @State private var tab: Tab = .notes
    @State private var title: String
    @State private var publishState: PublishState = .idle
    @State private var showDeleteConfirm = false
    @State private var showCatboxConfirm = false
    // Edit drafts live here, not in the tab views, so an accidental tab switch
    // can't destroy ten minutes of transcript fixes. nil = not editing.
    @State private var notesDraft: String?
    @State private var transcriptDraft: String?

    enum Tab: String, CaseIterable {
        case notes = "Notes"
        case transcript = "Transcript"
        case chat = "Chat"
    }

    enum PublishState: Equatable {
        case idle, working
        case done(URL)
        case failed(String)
    }

    init(meeting: Meeting) {
        _meeting = State(initialValue: meeting)
        _title = State(initialValue: meeting.title)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(20)
            Divider()
            content
        }
        .background(Theme.surface(scheme))
        .onChange(of: app.store.meetings) {
            if let fresh = app.store.meetings.first(where: { $0.id == meeting.id }) {
                meeting = fresh
                if !isEditingTitle { title = fresh.title }
            }
        }
    }

    @FocusState private var isEditingTitle: Bool

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                TextField("Meeting title", text: $title, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.parfait(24, .bold))
                    .lineLimit(2)
                    .focused($isEditingTitle)
                    .onSubmit(saveTitle)
                    .onChange(of: isEditingTitle) { if !isEditingTitle { saveTitle() } }
                Spacer()
                publishMenu
            }

            HStack(spacing: 8) {
                Text(meeting.createdAt.formatted(date: .complete, time: .shortened))
                    .font(.parfait(12))
                    .foregroundStyle(.secondary)
                if meeting.duration > 0 {
                    Text("·").foregroundStyle(.tertiary)
                    Text(TemplateRenderer.duration(meeting.duration))
                        .font(.parfait(12))
                        .foregroundStyle(.secondary)
                }
                if let source = meeting.sourceApp {
                    Text("·").foregroundStyle(.tertiary)
                    Text(source).font(.parfait(12)).foregroundStyle(.secondary)
                }
                ProviderBadge(provider: meeting.summaryProvider)
                Spacer()
                if let stage = app.processingStage[meeting.id] {
                    HStack(spacing: 5) {
                        ProgressView().controlSize(.small)
                        Text(stage).font(.parfait(12)).foregroundStyle(.secondary)
                    }
                }
            }

            if !meeting.attendees.isEmpty {
                HStack(spacing: 6) {
                    ForEach(meeting.attendees, id: \.self) { Chip(text: $0) }
                }
            }

            if let notice = meeting.notice {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Label(notice, systemImage: "exclamationmark.triangle")
                        .font(.parfait(12))
                        .foregroundStyle(.orange)
                    Button(meeting.state == .failed ? "Retry" : "Regenerate") {
                        Task { await app.retry(meetingID: meeting.id) }
                    }
                    .controlSize(.small)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
            }

            if case .done(let url) = publishState {
                HStack(spacing: 8) {
                    Label("Published", systemImage: "checkmark.circle.fill")
                        .font(.parfait(12, .medium))
                        .foregroundStyle(Theme.mint)
                    Link(url.absoluteString, destination: url)
                        .font(.parfait(12))
                        .lineLimit(1)
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(url.absoluteString, forType: .string)
                    }
                    .controlSize(.small)
                }
            } else if case .failed(let why) = publishState {
                Label(why, systemImage: "xmark.circle")
                    .font(.parfait(12))
                    .foregroundStyle(.orange)
            }

            Picker("", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Text($0.rawValue) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 340)
            .padding(.top, 6)
        }
    }

    private var publishMenu: some View {
        Menu {
            if GitHubGist.isAvailable {
                Button("Publish to secret Gist") { publish(.gist) }
            } else {
                Button("Publish to secret Gist (needs gh)") {}
                    .disabled(true)
            }
            Button("Publish public link…") { showCatboxConfirm = true }
            if let existing = meeting.publishedURL, let url = URL(string: existing) {
                Divider()
                Link("Open published page", destination: url)
            }
            Divider()
            Button("Export HTML…") { exportHTML() }
            Button("Show files in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting(
                    [app.store.archive.folder(for: meeting.id)])
            }
            Divider()
            Button("Delete meeting…", role: .destructive) { showDeleteConfirm = true }
        } label: {
            if publishState == .working {
                ProgressView().controlSize(.small)
            } else {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(.parfait(13, .medium))
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .confirmationDialog("Delete “\(meeting.title)”?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { app.store.delete(id: meeting.id) }
        } message: {
            Text("This permanently removes the audio, transcript, and notes from your Mac.")
        }
        .confirmationDialog("Publish a public link?", isPresented: $showCatboxConfirm) {
            Button("Upload to catbox.moe") { publish(.catbox) }
        } message: {
            Text("This uploads the notes and transcript to catbox.moe, a free third-party host. Anyone with the link can view them, and the page isn't tied to an account you control. For a link on your own GitHub, install gh and use “Publish to secret Gist”.")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .notes:
            NotesTab(meeting: meeting, draft: $notesDraft)
        case .transcript:
            TranscriptTab(meeting: meeting, draft: $transcriptDraft)
        case .chat:
            MeetingChatView(meeting: meeting, store: app.store)
        }
    }

    private func saveTitle() {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, t != meeting.title else { return }
        var m = meeting
        m.title = t
        app.store.upsert(m)
    }

    enum PublishTarget {
        case gist       // your own GitHub account, needs gh
        case catbox     // no install, public third-party host
    }

    private func publish(_ target: PublishTarget) {
        publishState = .working
        let m = meeting
        let summary = app.store.summary(for: m.id)
        let segments = app.store.transcript(for: m.id)
        Task {
            do {
                let html = HTMLExporter.html(meeting: m, summaryMarkdown: summary, segments: segments)
                let url: URL
                switch target {
                case .gist:
                    let (_, rendered) = try await GitHubGist.publish(
                        html: html,
                        filename: "meeting.html",
                        description: "Parfait meeting notes — \(m.title)")
                    url = rendered
                case .catbox:
                    url = try await CatboxPublisher.publish(html: html, filename: "meeting.html")
                }
                // Re-fetch: the upload took a while and the meeting may have been
                // edited (merge) or deleted (then don't resurrect it) meanwhile.
                if var fresh = app.store.meeting(id: m.id) {
                    fresh.publishedURL = url.absoluteString
                    app.store.upsert(fresh)
                }
                publishState = .done(url)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url.absoluteString, forType: .string)
            } catch {
                publishState = .failed(error.localizedDescription)
            }
        }
    }

    private func exportHTML() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = meeting.title.replacingOccurrences(of: "/", with: "-") + ".html"
        panel.allowedContentTypes = [.html]
        guard panel.runModal() == .OK, let dest = panel.url else { return }
        let html = HTMLExporter.html(
            meeting: meeting,
            summaryMarkdown: app.store.summary(for: meeting.id),
            segments: app.store.transcript(for: meeting.id))
        try? html.data(using: .utf8)?.write(to: dest)
    }
}
