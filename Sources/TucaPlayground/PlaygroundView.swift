import AppKit
import SwiftUI
import TucaCharacter
import TucaCore

/// Envolve o TucaCharacterView (Core Animation) para o SwiftUI.
struct CharacterBox: NSViewRepresentable {
    @ObservedObject var model: PlaygroundModel

    func makeNSView(context: Context) -> TucaCharacterView {
        let v = TucaCharacterView(frame: .zero)
        model.register(v)
        return v
    }

    func updateNSView(_ v: TucaCharacterView, context: Context) {
        model.configure(v)
    }
}

struct PlaygroundRoot: View {
    @ObservedObject var model: PlaygroundModel

    var body: some View {
        HStack(spacing: 0) {
            preview
            Divider()
            controls.frame(width: 340)
        }
        .frame(minWidth: 1100, minHeight: 740)
    }

    // MARK: Prévia

    private var preview: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18).fill(Color(nsColor: model.backdrop.color))
                CharacterBox(model: model)
                    .frame(width: model.size * 1.18 * 1.78, height: model.size * 1.32)
                    .id(model.size)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 6) {
                Text("Tamanhos (altura do personagem)").font(.caption).foregroundStyle(.secondary)
                HStack(alignment: .bottom, spacing: 12) {
                    ForEach(PlaygroundModel.sizes, id: \.self) { s in
                        VStack(spacing: 4) {
                            CharacterBox(model: model)
                                .frame(width: min(s, 128) * 1.18 * 1.78, height: min(s, 128) * 1.32)
                                .background(Color(nsColor: model.backdrop.color), in: RoundedRectangle(cornerRadius: 6))
                            Text(s > 128 ? "\(Int(s)) (na prévia)" : "\(Int(s)) px").font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Text(model.diagnostics)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
    }

    // MARK: Controles

    private var controls: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Tuca · Character Playground").font(.headline)
                Text("Passe o mouse, clique e arraste arquivos sobre o Tuca. Os textos são só diagnóstico.")
                    .font(.caption).foregroundStyle(.secondary)

                group("Estados") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        ForEach(TucaVisualState.allCases, id: \.self) { s in
                            Button { model.state = s } label: {
                                Text(s.label).frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(model.state == s ? .orange : .gray)
                        }
                    }
                    Button { model.tour() } label: {
                        Label("Pensando → Lendo → Escrevendo → Sucesso", systemImage: "play.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).tint(.orange).disabled(model.touring)
                }

                group("Interações") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        action("Piscar", "eye") { model.blink() }
                        action("Clique", "hand.tap") { model.click() }
                        action("Cliques repetidos", "hand.tap.fill") { model.multiClick() }
                        action("Receber arquivo", "doc.badge.arrow.up") { model.receiveFile() }
                        action("Dormir e acordar", "sun.max") { model.wake() }
                    }
                    Toggle("Hover (simulado)", isOn: $model.hoverSim)
                    Toggle("Arquivo sobre o Tuca (simulado)", isOn: $model.dragSim)
                    Toggle("Seguir o cursor", isOn: $model.followCursor)
                    if !model.lastDrop.isEmpty {
                        Text("Recebido: \(model.lastDrop)").font(.caption).foregroundStyle(.secondary)
                    }
                }

                group("Prévia") {
                    Picker("Tamanho", selection: $model.size) {
                        ForEach(PlaygroundModel.sizes, id: \.self) { Text("\(Int($0)) px").tag($0) }
                    }
                    Picker("Movimento", selection: $model.motion) {
                        ForEach(MotionMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Picker("Fundo", selection: $model.backdrop) {
                        ForEach(Backdrop.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .padding(18)
        }
    }

    private func group<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
            content()
        }
    }

    private func action(_ title: String, _ icon: String, _ run: @escaping () -> Void) -> some View {
        Button(action: run) { Label(title, systemImage: icon).frame(maxWidth: .infinity) }
            .buttonStyle(.bordered)
    }
}
