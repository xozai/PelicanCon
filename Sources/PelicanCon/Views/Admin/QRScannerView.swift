import SwiftUI
import AVFoundation

// MARK: - UIKit scanner controller

final class QRScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?
    private var session: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session?.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session?.stopRunning()
    }

    private func setupCamera() {
        let session = AVCaptureSession()
        guard let device = AVCaptureDevice.default(for: .video),
              let input  = try? AVCaptureDeviceInput(device: device) else { return }

        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame       = view.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        self.previewLayer = preview

        // Aim box overlay
        let boxSize: CGFloat = 220
        let boxOrigin = CGPoint(
            x: (view.bounds.width - boxSize) / 2,
            y: (view.bounds.height - boxSize) / 2
        )
        let box = UIView(frame: CGRect(origin: boxOrigin, size: CGSize(width: boxSize, height: boxSize)))
        box.layer.borderColor  = UIColor.white.cgColor
        box.layer.borderWidth  = 2
        box.layer.cornerRadius = 12
        view.addSubview(box)

        self.session = session
    }

    // AVCaptureMetadataOutputObjectsDelegate
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let obj  = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = obj.stringValue,
              !value.isEmpty else { return }
        session?.stopRunning()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onScan?(value)
    }
}

// MARK: - SwiftUI wrapper

struct QRScannerRepresentable: UIViewControllerRepresentable {
    var onScan: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerController {
        let vc = QRScannerController()
        vc.onScan = onScan
        return vc
    }

    func updateUIViewController(_ uiViewController: QRScannerController, context: Context) {}
}

// MARK: - Admin check-in scanner sheet

struct QRScannerView: View {
    @Environment(\.dismiss) var dismiss
    @State private var scannedUID: String?
    @State private var checkedInName: String?
    @State private var isProcessing  = false
    @State private var errorMessage: String?
    @State private var showSuccess   = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if showSuccess, let name = checkedInName {
                    // Success overlay
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 72))
                            .foregroundColor(Theme.success)
                        Text("Checked In!")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        Text(name)
                            .font(.title3)
                            .foregroundColor(.gray)
                        Button("Scan Next") {
                            scannedUID   = nil
                            checkedInName = nil
                            showSuccess  = false
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.horizontal, 60)
                        .padding(.top, 12)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                } else {
                    // Camera viewfinder
                    QRScannerRepresentable { uid in
                        guard !isProcessing else { return }
                        isProcessing = true
                        Task { await processCheckIn(uid: uid) }
                    }
                    .ignoresSafeArea()

                    // Instruction label
                    VStack {
                        Spacer()
                        Text("Aim at an attendee's check-in QR code")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.55))
                            .clipShape(Capsule())
                            .padding(.bottom, 50)
                    }

                    if isProcessing {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        ProgressView().tint(.white).scaleEffect(1.5)
                    }

                    if let err = errorMessage {
                        VStack {
                            Text(err)
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.red.opacity(0.85))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .padding(.top, 60)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Check-In Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Process scanned UID

    private func processCheckIn(uid: String) async {
        errorMessage = nil
        do {
            let user = try await UserService.shared.fetchUser(id: uid)

            // Mark checked in
            try? await Firestore.firestore()
                .collection("users")
                .document(uid)
                .updateData(["checkedIn": true])

            // Award checked-in badge
            await BadgeService.shared.awardBadge(.checkedIn, to: uid)

            await MainActor.run {
                checkedInName = user.fullDisplayName
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showSuccess  = true
                }
                isProcessing = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Could not find attendee. Make sure they're registered."
                isProcessing = false
            }
        }
    }
}
