/*
 See LICENSE folder for this sample’s licensing information.

 Abstract:
 Code that displays a UIAlert for a view controller or opens Settings.
 */

import Combine
import UIKit

import LinkPresentation

func hoursAgo(_ hours: Int, minutes: Int = 0) -> Date { Date(timeIntervalSinceNow: TimeInterval(-hours * 60 * 60 - minutes * 60)) }

func daysAgo(_ days: Int) -> Date { hoursAgo(days * 24) }

func showError(_ error: Error, from viewController: UIViewController) {
    let alert = UIAlertController(title: NSLocalizedString("ERROR", comment: "Title"), message: error.localizedDescription, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Button"), style: .cancel))
    viewController.present(alert, animated: true, completion: nil)
}

func openSettings(from viewController: UIViewController) {
    viewController.view.window?.windowScene?.open(URL(string: UIApplication.openSettingsURLString)!, options: nil, completionHandler: nil)
}

class JsonItem: NSObject, UIActivityItemSource {
    let url: URL
    let title: String
    init(url: URL, title: String) {
        self.url = url
        self.title = title
    }

    func activityViewControllerPlaceholderItem(_: UIActivityViewController) -> Any {
        "Exposure data as json files"
    }

    func activityViewController(_: UIActivityViewController, itemForActivityType _: UIActivity.ActivityType?) -> Any? {
        url
    }

    func activityViewController(_: UIActivityViewController,
                                subjectForActivityType _: UIActivity.ActivityType?) -> String {
        title
    }

    func activityViewControllerLinkMetadata(_: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.originalURL = url
        metadata.url = url

        metadata.title = title
        return metadata
    }
}
