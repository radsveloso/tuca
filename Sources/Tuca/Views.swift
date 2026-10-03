import SwiftUI
import TucaCharacter
import TucaCore

struct NotchShape: Shape {
    var radius: CGFloat
    var animatableData: CGFloat {
        get { radius }
        set { radius = newValue }
    }

    func path(in r: CGRect) -> Path {
        let rad = min(radius, r.height / 2, r.width / 2)
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - rad))
        p.addQuadCurve(to: CGPoint(x: r.maxX - rad, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + rad, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - rad), control: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

struct RootView: View {
    @ObservedObject var c: NotchController
    @ObservedObject var store: SessionStore
    @ObservedObject var chat: ChatEngine

    var body: some View {
        let size = c.shapeSize
        let radius: CGFloat = c.expanded ? 26 : 12
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                NotchShape(radius: radius)
                    .fill(Color.black)
                    .shadow(color: .black.opacity(c.expanded ? 0.5 : 0), radius: 16, y: 8)
                Group {
                    if c.expanded {
                        ExpandedView(c: c, store: store, chat: chat)
                            .padding(.top, max(c.geo.notchHeight - 4, 8))
                            .transition(.opacity)
                    } else if c.hasActivity {
                        CollapsedView(store: store, chat: chat, height: c.geo.notchHeight)
                            .transition(.opacity)
                    }
                }
                .clipShape(NotchShape(radius: radius))
                if c.expanded && c.dropTargeted {
                    DropOverlay()
                        .clipShape(NotchShape(radius: radius))
                        .transition(.opacity)
                }
            }
            .frame(width: size.width, height: size.height)
            .dropDestination(for: URL.self) { urls, _ in
                c.handleDrop(urls)
                return !urls.isEmpty
            } isTargeted: { c.dropTargeted = $0 }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.36, dampingFraction: 0.82), value: c.expanded)
        .animation(.spring(response: 0.36, dampingFraction: 0.82), value: c.hasActivity)
        .environment(\.colorScheme, .dark)
    }
}

struct CollapsedView: View {
    @ObservedObject var store: SessionStore
    @ObservedObject var chat: ChatEngine
    let height: CGFloat

    var body: some View {
        HStack {
            // 24 a 32 pt: silhueta, olho e bico.
            TucaCharacterSlot(margins: CGSize(width: 1.04, height: 1.06))
                .frame(width: (height - 4) * 1.78 * 1.04 / 1.06, height: height - 4)
            Spacer()
            StatusBadge(count: store.workingCount)
        }
        .padding(.horizontal, 14)
        .frame(height: height)
    }
}

/// Lado direito do notch: símbolo do estado (forma + cor), sem depender só de cor.
struct StatusBadge: View {
    let count: Int

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { tl in
            let s = TucaFX.shared.state(at: tl.date)
            HStack(spacing: 4) {
                switch s {
                case .idle, .sleeping:
                    EmptyView()
                case .needsAttention:
                    Image(systemName: s.symbol).font(.system(size: 13, weight: .bold)).foregroundStyle(s.tint)
                default:
                    Image(systemName: s.symbol).font(.system(size: 11, weight: .semibold)).foregroundStyle(s.tint)
                }
                if count > 1 {
                    Text("\(count)").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.white)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(s.label)
        }
    }
}

struct PulsingDot: View {
    let color: Color
    var size: CGFloat = 8

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let k = 0.5 + 0.5 * sin(t * 4)
            ZStack {
                Circle().fill(color.opacity(0.35 * (1 - k))).frame(width: size * (1 + k), height: size * (1 + k))
                Circle().fill(color).frame(width: size, height: size)
            }
            .frame(width: size * 2, height: size * 2)
        }
    }
}

struct ExpandedView: View {
    @ObservedObject var c: NotchController
    @ObservedObject var store: SessionStore
    @ObservedObject var chat: ChatEngine

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                TucaCharacterSlot(margins: CGSize(width: 1.08, height: 1.14))
                    .frame(width: 70, height: 42)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Tuca")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    TucaStateLabel()
                }
                Picker("", selection: $c.tab) {
                    Text("Sessões").tag(IslandTab.sessions)
                    Text("Chat").tag(IslandTab.chat)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 170)
                Spacer()
                Button { c.pinned.toggle() } label: {
                    Image(systemName: c.pinned ? "pin.fill" : "pin")
                }
                .buttonStyle(.plain)
                .foregroundStyle(c.pinned ? Color.orange : Color.secondary)
                .help("Manter aberto")
            }
            Group {
                switch c.tab {
                case .sessions: SessionsView(store: store, c: c)
                case .chat: ChatView(chat: chat)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .onExitCommand { c.collapse() }
    }
}

// MARK: - Sessões

struct SessionsView: View {
    @ObservedObject var store: SessionStore
    @ObservedObject var c: NotchController

    var body: some View {
        if store.sessions.isEmpty {
            VStack(spacing: 10) {
                Spacer()
                Text("Nenhuma sessão ativa").foregroundStyle(.secondary)
                if !store.hooksInstalled {
                    Text("Instale os hooks para ver o Claude Code trabalhando aqui.")
                        .font(.caption).foregroundStyle(.tertiary)
                    Button("Instalar hooks do Claude Code") { c.onInstallHooks?() }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                } else {
                    Text("Abra o Claude Code em qualquer projeto e ele aparece aqui.")
                        .font(.caption).foregroundStyle(.tertiary)
                }
                Spacer()
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(store.sessions) { s in
                        SessionRow(s: s) { store.remove(s.id) }
                    }
                }
            }
            .scrollIndicators(.never)
        }
    }
}

struct SessionRow: View {
    let s: AgentSession
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            if s.state == .working || s.state == .needsYou {
                PulsingDot(color: s.state.color, size: 7)
            } else {
                Circle().fill(s.state.color).frame(width: 7, height: 7).frame(width: 14, height: 14)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(s.project)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(s.state.label)
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(s.state.color.opacity(0.18), in: Capsule())
                        .foregroundStyle(s.state.color)
                }
                Text(s.detail)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 8)
            TimelineView(.periodic(from: .now, by: 20)) { _ in
                Text(Self.ago(s.updated)).font(.system(size: 10)).foregroundStyle(.tertiary)
            }
            Button(action: onClose) { Image(systemName: "xmark").font(.system(size: 9, weight: .bold)) }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
                .help("Remover da lista")
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(Color.white.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    static func ago(_ d: Date) -> String {
        let s = Int(Date().timeIntervalSince(d))
        if s < 30 { return "agora" }
        if s < 3600 { return "\(max(1, s / 60)) min" }
        return "\(s / 3600) h"
    }
}

// MARK: - Chat

struct ChatView: View {
    @ObservedObject var chat: ChatEngine
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                ForEach(Provider.allCases.filter { !$0.optional || chat.available[$0] != nil }) { p in
                    ProviderChip(p: p, selected: chat.provider == p, installed: chat.available[p] != nil) {
                        chat.provider = p
                    }
                    .disabled(chat.isRunning)
                }
                Spacer()
                Button { chat.newChat() } label: { Image(systemName: "square.and.pencil") }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Nova conversa")
                    .disabled(chat.isRunning)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if chat.messages.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Converse com o \(chat.provider.label)")
                                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                                Text("Usa o login da CLI \(chat.provider.binary) do seu Mac. Sem API key.")
                                    .font(.system(size: 11)).foregroundStyle(.secondary)
                                Text("Arraste imagens, PDFs ou planilhas até o notch para perguntar sobre eles.")
                                    .font(.system(size: 11)).foregroundStyle(.tertiary)
                            }
                            .padding(.top, 6)
                        }
                        ForEach(chat.messages) { m in
                            MessageBubble(m: m).id(m.id)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.never)
                .onChange(of: chat.revision) { _, _ in
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }

            if !chat.attachments.isEmpty || chat.notice != nil {
                VStack(alignment: .leading, spacing: 4) {
                    ScrollView(.horizontal) {
                        HStack(spacing: 6) {
                            ForEach(chat.attachments) { a in
                                AttachmentChip(a: a) { chat.removeAttachment(a.id) }
                            }
                        }
                    }
                    .scrollIndicators(.never)
                    if let n = chat.notice {
                        Text(n).font(.system(size: 10)).foregroundStyle(.orange)
                    }
                }
            }

            HStack(spacing: 8) {
                TextField(chat.attachments.isEmpty ? "Pergunte ao \(chat.provider.label)…" : "Pergunte sobre o arquivo…", text: $chat.draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .lineLimit(1...4)
                    .focused($focused)
                    .onSubmit(send)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                if chat.isRunning {
                    Button { chat.stop() } label: {
                        Image(systemName: "stop.circle.fill").font(.system(size: 24))
                    }
                    .buttonStyle(.plain).foregroundStyle(.white)
                    .help("Parar")
                } else {
                    Button(action: send) {
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: 24))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(chat.draft.trimmingCharacters(in: .whitespaces).isEmpty && chat.attachments.isEmpty ? Color.gray : chat.provider.color)
                    .keyboardShortcut(.return, modifiers: .command)
                }
            }
        }
        .onAppear { focused = true }
    }

    private func send() {
        let t = chat.draft
        guard !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !chat.attachments.isEmpty, !chat.isRunning else { return }
        chat.draft = ""
        chat.send(t)
    }
}

struct ProviderChip: View {
    let p: Provider
    let selected: Bool
    let installed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Circle().fill(installed ? p.color : Color.gray.opacity(0.6)).frame(width: 7, height: 7)
                Text(p.label).font(.system(size: 11, weight: .semibold))
            }
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(Color.white.opacity(selected ? 0.17 : 0.05), in: Capsule())
            .overlay(Capsule().stroke(selected ? p.color.opacity(0.7) : .clear, lineWidth: 1))
            .foregroundStyle(installed ? Color.white : Color.gray)
        }
        .buttonStyle(.plain)
        .help(installed ? "Usa o login da CLI \(p.binary)" : "Não instalado: \(p.installHint)")
    }
}

struct MessageBubble: View {
    let m: ChatMessage

    var body: some View {
        switch m.role {
        case .user:
            VStack(alignment: .trailing, spacing: 4) {
                if !m.files.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "paperclip")
                        Text(m.files.joined(separator: ", ")).lineLimit(1).truncationMode(.middle)
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 70)
                }
                if !m.text.isEmpty {
                    userBubble
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        case .assistant:
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Circle().fill(m.provider.color).frame(width: 6, height: 6)
                    Text(m.provider.label).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                }
                if m.text.isEmpty {
                    TypingDots(color: m.provider.color)
                } else {
                    Text(Self.markdown(m.text))
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.92))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        case .error:
            Text(m.text)
                .font(.system(size: 12))
                .foregroundStyle(Color(red: 1, green: 0.45, blue: 0.42))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var userBubble: some View {
        Text(m.text)
            .font(.system(size: 13))
            .foregroundStyle(.white)
            .textSelection(.enabled)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.leading, 70)
    }

    static func markdown(_ s: String) -> AttributedString {
        (try? AttributedString(markdown: s, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(s)
    }
}

struct TypingDots: View {
    let color: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                        .opacity(0.35 + 0.65 * max(0, sin(t * 5 - Double(i) * 0.7)))
                }
            }
            .padding(.vertical, 4)
        }
    }
}

struct AttachmentChip: View {
    let a: Attachment
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            if a.isImage, let img = NSImage(contentsOf: a.url) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            } else {
                Image(systemName: a.symbol)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
            }
            Text(a.name)
                .font(.system(size: 11))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 150, alignment: .leading)
            Button(action: onRemove) {
                Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.leading, 4).padding(.trailing, 9).padding(.vertical, 4)
        .background(Color.white.opacity(0.1), in: Capsule())
    }
}

struct DropOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.88)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.8), style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
                .padding(14)
            VStack(spacing: 10) {
                TucaCharacterSlot().frame(width: 190, height: 104)
                Text("Solte para anexar")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Imagens, PDFs, planilhas, código")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
