//
//  ContentView.swift
//
//  Created by Bill Pugh on 5/11/20.
//

import Combine
import ExposureNotification
import LinkPresentation
import SwiftUI

struct ActivityIndicatorView: UIViewRepresentable {
    @Binding var isAnimating: Bool
    func makeUIView(context _: Context) -> UIActivityIndicatorView {
        let result = UIActivityIndicatorView()
        result.style = .large
        return result
    }

    func updateUIView(_ uiView: UIActivityIndicatorView, context _: Context) {
        if isAnimating {
            uiView.startAnimating()
        } else {
            uiView.stopAnimating()
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]?
    @Binding var isPresented: Bool

    func makeUIViewController(context _: UIViewControllerRepresentableContext<ActivityView>) -> UIActivityViewController {
        let result = UIActivityViewController(activityItems: activityItems,
                                              applicationActivities: applicationActivities)
        result.excludedActivityTypes = [UIActivity.ActivityType.addToReadingList,
                                        UIActivity.ActivityType.assignToContact,
                                        UIActivity.ActivityType.copyToPasteboard,
                                        UIActivity.ActivityType.markupAsPDF,
                                        UIActivity.ActivityType.openInIBooks,
                                        UIActivity.ActivityType.postToFacebook,
                                        UIActivity.ActivityType.postToFlickr,
                                        UIActivity.ActivityType.postToTencentWeibo,
                                        UIActivity.ActivityType.postToTwitter,
                                        UIActivity.ActivityType.postToVimeo,
                                        UIActivity.ActivityType.postToWeibo,
                                        UIActivity.ActivityType.print,
                                        UIActivity.ActivityType.saveToCameraRoll]
        result.completionWithItemsHandler = { (activityType: UIActivity.ActivityType?, completed:
            Bool, _: [Any]?, error: Error?) in
        print("activity: \(String(describing: activityType))")

        if completed {
            print("share completed")
            self.isPresented = false
            return
        } else {
            print("cancel")
        }
        if let shareError = error {
            print("error while sharing: \(shareError.localizedDescription)")
        }
        }
        return result
    }

    func updateUIViewController(_: UIActivityViewController,
                                context _: UIViewControllerRepresentableContext<ActivityView>) {}
}

struct StatusView: View {
    @EnvironmentObject var localStore: LocalStore
    @State private var showingSheet = false
    @State var showsAlert = false
    @State private var shareURL: URL?
    @EnvironmentObject var framework: ExposureFramework
    @State var computingKeys = false
    var body: some View {
        Form {
            Section(header: Text("User Info").font(.title)) {
                HStack {
                    Text("User name: ")
                    TextField("User name", text: self.$localStore.userName, onCommit: { self.localStore.save() })
                }.padding(.horizontal)
            }

            Section(header: Text("Actions").font(.title)) {
                // Share diagnosis keys
                Button(action: {
                    self.computingKeys = true
                    self.framework.getAndPackageKeys(userName: self.localStore.userName, tRiskLevel: ENRiskLevel(self.localStore.transmissionRiskLevel)) {
                        print("getAndPackageKeys done")
                        self.showingSheet = true
                        self.computingKeys = false
                    }
                }
                ) {
                    ZStack {
                        HStack { Text("Share diagnosis keys  \(self.framework.keysExportedMessage)").font(.headline)
                            Image(systemName: "square.and.arrow.up").font(.headline)
                        }
                        ActivityIndicatorView(isAnimating: $computingKeys)
                    }
                }.padding(.vertical).sheet(isPresented: $showingSheet, onDismiss: { print("share sheet dismissed") },
                                           content: {
                                               ActivityView(activityItems: DiagnosisKeyItem(self.framework.keyCount, self.localStore.userName, self.framework.keyURL!).itemsToShare() as [Any], applicationActivities: nil, isPresented: self.$showingSheet)
                            })

                // Show exposures
                NavigationLink(destination: ExposuresView(), tag: "exposures", selection: $localStore.viewShown) {
                    Text("Show exposures").font(.headline)
                }
                .padding(.vertical)

                // Go Deeper
                Button(action: {
                    LocalStore.shared.goDeeper()
                }
                ) { Text("Go deeper") }

                // About
                NavigationLink(destination: MyAboutView(), tag: "about", selection: $localStore.viewShown) {
                    Text("About GAEN Explorer").font(.headline)
                }
                .padding(.vertical)
            } // Group
            Section(header: Text("Framework").font(.title)) {
                Toggle(isOn: self.$framework.isEnabled) {
                    Text("Toggle notifications")
                }.padding()

                HStack {
                    Text(framework.exposureNotificationStatus.description).font(.headline)
                    Spacer()
                    Text(framework.authorizationStatus.description).font(.headline)
                }.padding(.horizontal).foregroundColor(self.framework.feasible ? .primary : .red)
            }
        } // VStack
    } // var body
} // end status view

struct ContentView: View {
    var body: some View {
        NavigationView {
            StatusView().navigationBarTitle("GAEN Explorer")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static let models: [String] = ["iPhone SE", "iPhone 11 Pro Max"]
    static let localStore = LocalStore(userName: "Alice", transmissionRiskLevel: 6, testData: [BatchExposureInfo.testData])

    static var previews: some View {
        ForEach(models, id: \.self) { name in ContentView().environmentObject(localStore)
            .environmentObject(ExposureFramework.shared)
            .previewDevice(PreviewDevice(rawValue: name))
            .previewDisplayName(name)
        }
    }
}
