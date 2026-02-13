import SwiftUI

struct IndeterminateProgressBar: View {
    @State private var offsetX: CGFloat = -1.0

    var body: some View {
        GeometryReader { geo in
            let sliderWidth = geo.size.width * 0.4
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.orange.opacity(0.2))

                RoundedRectangle(cornerRadius: 1.5)
                    .fill(
                        LinearGradient(
                            colors: [.orange, .orange.opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: sliderWidth)
                    .offset(x: offsetX * (geo.size.width - sliderWidth))
            }
        }
        .frame(height: 3)
        .clipShape(RoundedRectangle(cornerRadius: 1.5))
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                offsetX = 1.0
            }
        }
    }
}

struct FloatingPanelView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 12) {
            // Status indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                    .overlay {
                        if appState.recordingState.isRecording || appState.recordingState.isProcessing {
                            Circle()
                                .fill(statusColor.opacity(0.5))
                                .frame(width: 18, height: 18)
                                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: appState.recordingState)
                        }
                    }

                if appState.recordingState.isProcessing, let startTime = appState.processingStartTime {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let elapsed = Int(context.date.timeIntervalSince(startTime))
                        Text("Processing... \(elapsed)s")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                    }
                } else {
                    Text(appState.recordingState.statusText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                }

                Spacer()
            }

            // Indeterminate progress bar
            if appState.recordingState.isProcessing {
                IndeterminateProgressBar()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Transcript display
            if !appState.rawTranscript.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Raw:")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text(appState.rawTranscript)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !appState.refinedText.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Refined:")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(appState.refinedText)
                        .font(.system(size: 12))
                        .foregroundColor(.primary)
                        .lineLimit(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .frame(width: 320)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.3), value: appState.recordingState)
    }

    private var statusColor: Color {
        switch appState.recordingState {
        case .idle: return .gray
        case .recording: return .red
        case .processing: return .orange
        case .injecting: return .green
        case .error: return .red
        }
    }
}
