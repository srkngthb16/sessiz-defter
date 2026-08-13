import SwiftUI
import UIKit

public enum SnapshotRenderer {
    /// Görünümü gerçek bir pencerede, verilen trait'lerle çizer.
    /// ImageRenderer yerine UIHostingController kullanılır: ImageRenderer
    /// Dynamic Type ve userInterfaceStyle geçersiz kılmalarını taşımaz.
    @MainActor
    public static func image<V: View>(
        of view: V,
        variant: SnapshotVariant,
        size: CGSize,
        scale: CGFloat = SnapshotDevice.scale
    ) -> UIImage {
        let host = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.overrideUserInterfaceStyle = variant.style
        window.traitOverrides.preferredContentSizeCategory = variant.sizeCategory
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.backgroundColor = .clear

        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        // Trait geçersiz kılmaları uygulandıktan sonra ikinci geçiş: XXL'de
        // yükseklik ilk geçişte henüz oturmuyor.
        window.layoutIfNeeded()
        // SwiftUI ilk layout'u bir sonraki çalıştırma döngüsünde uyguluyor;
        // bu tur olmadan görüntü boş çıkıyor.
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        window.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        // drawHierarchy, uygulama host'u olmayan test paketinde boş kare üretiyor;
        // layer.render ekran güncellemesine bağlı değil.
        return renderer.image { context in
            window.layer.render(in: context.cgContext)
        }
    }
}
