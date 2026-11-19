import UIKit

class Toast {
    private static var toastLabel: UILabel?

    static func show(message: String, duration: Double = 2.0) {
        guard let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow }) else {
            return
        }

        // Remove any existing toast
        toastLabel?.removeFromSuperview()

        let label = UILabel()
        toastLabel = label
        label.text = message
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 14)
        label.numberOfLines = 0
        label.layer.cornerRadius = 10
        label.clipsToBounds = true
        label.alpha = 0

        // 💡 Dynamic text color
        label.textColor = UIColor { trait in
            return trait.userInterfaceStyle == .dark ? .white : .black
        }

        // 💡 Dynamic background color
        label.backgroundColor = UIColor { trait in
            return trait.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.15)
                : UIColor.black.withAlphaComponent(0.75)
        }

        let maxSize = CGSize(width: window.frame.width - 40, height: window.frame.height)
        let expectedSize = label.sizeThatFits(maxSize)
        let width = min(expectedSize.width + 20, maxSize.width)
        let height = expectedSize.height + 16

        label.frame = CGRect(
            x: (window.frame.width - width) / 2,
            y: window.frame.height - height - 80,
            width: width,
            height: height
        )

        window.addSubview(label)

        UIView.animate(withDuration: 0.5, animations: {
            label.alpha = 1.0
        }) { _ in
            UIView.animate(withDuration: 0.5, delay: duration, options: .curveEaseOut, animations: {
                label.alpha = 0.0
            }, completion: { _ in
                label.removeFromSuperview()
                if toastLabel == label {
                    toastLabel = nil
                }
            })
        }
    }
}
