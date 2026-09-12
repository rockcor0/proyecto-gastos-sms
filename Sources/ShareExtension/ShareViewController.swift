import UIKit
import SwiftUI
import UniformTypeIdentifiers

/// The extension's principal class (`NSExtensionPrincipalClass` in `project.yml`). Share
/// Extensions don't get a SwiftUI `App` entry point — this plain `UIViewController` pulls the
/// shared plain text out of `extensionContext`, then hosts a SwiftUI view for the rest of the UI.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        extractSharedText { [weak self] text in
            DispatchQueue.main.async {
                self?.presentConfirmation(text: text)
            }
        }
    }

    private func extractSharedText(completion: @escaping (String?) -> Void) {
        guard
            let item = extensionContext?.inputItems.first as? NSExtensionItem,
            let provider = item.attachments?.first(where: {
                $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
            })
        else {
            completion(nil)
            return
        }

        provider.loadObject(ofClass: String.self) { text, _ in
            completion(text)
        }
    }

    private func presentConfirmation(text: String?) {
        let hostingController = UIHostingController(
            rootView: ShareExtensionView(sharedText: text, onFinish: { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil)
            })
        )
        addChild(hostingController)
        hostingController.view.frame = view.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
    }
}
