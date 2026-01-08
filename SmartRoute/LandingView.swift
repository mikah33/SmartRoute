import SwiftUI
import AVKit

struct VideoPlayerView: UIViewRepresentable {
    let videoName: String
    let videoExtension: String

    func makeUIView(context: Context) -> UIView {
        let view = PlayerUIView(videoName: videoName, videoExtension: videoExtension)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

class PlayerUIView: UIView {
    private var playerLayer = AVPlayerLayer()
    private var playerLooper: AVPlayerLooper?

    init(videoName: String, videoExtension: String) {
        super.init(frame: .zero)

        guard let path = Bundle.main.path(forResource: videoName, ofType: videoExtension) else {
            print("Video file not found: \(videoName).\(videoExtension)")
            return
        }

        let url = URL(fileURLWithPath: path)
        let asset = AVAsset(url: url)
        let item = AVPlayerItem(asset: asset)

        let player = AVQueuePlayer(playerItem: item)
        playerLooper = AVPlayerLooper(player: player, templateItem: item)

        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(playerLayer)

        player.isMuted = true
        player.play()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}

struct LandingView: View {
    @Binding var showLanding: Bool
    @State private var logoOpacity: Double = 0
    @State private var buttonOpacity: Double = 0

    var body: some View {
        ZStack {
            // Video background
            VideoPlayerView(videoName: "smartroute_video", videoExtension: "mp4")
                .ignoresSafeArea()

            // Dark overlay for better text visibility
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            // Content
            VStack(spacing: 40) {
                Spacer()

                // Logo/Title area
                VStack(spacing: 16) {
                    Text("SmartRoute")
                        .font(.custom("DM Sans", size: 42).weight(.bold))
                        .foregroundColor(.white)

                    Text("Optimize your routes. Save time.")
                        .font(.custom("DM Sans", size: 18).weight(.medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                .opacity(logoOpacity)

                Spacer()

                // Get Started button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showLanding = false
                    }
                }) {
                    Text("Get Started")
                        .font(.custom("DM Sans", size: 18).weight(.semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .cornerRadius(28)
                }
                .padding(.horizontal, 32)
                .opacity(buttonOpacity)

                // Sign in link
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showLanding = false
                    }
                }) {
                    Text("Already have an account? Sign In")
                        .font(.custom("DM Sans", size: 16).weight(.medium))
                        .foregroundColor(.white.opacity(0.9))
                }
                .opacity(buttonOpacity)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.8).delay(0.3)) {
                logoOpacity = 1
            }
            withAnimation(.easeIn(duration: 0.8).delay(0.8)) {
                buttonOpacity = 1
            }
        }
    }
}

#Preview {
    LandingView(showLanding: .constant(true))
}
