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
                                        UIActivity.ActivityType.saveToCameraRoll,
                                        UIActivity.ActivityType(rawValue: "com.apple.reminders.sharingextension"),
                                        UIActivity.ActivityType(rawValue: "com.apple.mobilenotes.SharingExtension")]
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
        VStack {
            // Onboarding
            NavigationLink(destination: OnboardingView(), tag: "onboarding", selection: $localStore.viewShown) {
                // Text("Onboarding").font(.headline).padding()
                EmptyView()
            }
            Form {
                // MARK: Status

                Section(header: Text(ExposureFramework.isV2() ? "V2 Status" : "Status").font(.title)) {
                    HStack {
                        Text("User name: ")
                        TextField("User name", text: self.$localStore.userName)
                    }.padding(.horizontal)

                    Toggle(isOn: self.$framework.observedIsEnabled) {
                        Text("Scanning for encounters")
                    }.padding(.horizontal).foregroundColor(self.framework.feasible ? .primary : .red)

                    // About
                    NavigationLink(destination: MyAboutView(), tag: "about", selection: $localStore.viewShown) {
                        Text("About").font(.headline).padding(.horizontal)
                    }
                } // Section

                // MARK: Actions

                Section(header: Text("Actions").font(.title)) {
                    // Share diagnosis keys
                    Button(action: {
                        self.computingKeys = true
                        self.localStore.getAndPackageKeys { url in
                            print("getAndPackageKeys done")
                            if url != nil {
                                self.showingSheet = true
                                LocalStore.shared.addDiaryEntry(.keysShared)
                            }
                            self.computingKeys = false
                        }
                    }
                    ) {
                        ZStack {
                            HStack { Text(localStore.userName.isEmpty ? "Provide a user name before sharing keys" : "Share keys")
                                Spacer()
                                Image(systemName: "square.and.arrow.up")
                            }.font(.headline).foregroundColor(.primary)
                            ActivityIndicatorView(isAnimating: $computingKeys)
                        }
                    }.padding().disabled(localStore.userName.isEmpty).sheet(isPresented: $showingSheet, onDismiss: { print("share sheet dismissed") },
                                                                            content: {
                                                                                ActivityView(activityItems: DiagnosisKeyItem(self.framework.keyCount, self.localStore.userName, self.framework.keyURL!).itemsToShare() as [Any], applicationActivities: nil, isPresented: self.$showingSheet)
                                                                            })

                    // Show exposures
                    NavigationLink(destination: ExposuresView(), tag: "exposures", selection: $localStore.viewShown) {
                        Text(localStore.showEncountersMsg).font(.headline).padding()
                    }
                    NavigationLink(destination: MultipeerExperimentView(), tag: "experiment", selection: $localStore.viewShown) {
                        Text(localStore.experimentMessage ?? "Experiment").font(.headline).padding()
                    }.disabled(self.localStore.userName.isEmpty)

                    if false {
                        Button(action: { self.framework.analyzeRandomKeys(numKeys: 3_000_000) }) { Text("Analyze 3M random keys") }
                        NavigationLink(destination: DiaryView(), tag: "diary", selection: $localStore.viewShown) {
                            Text("Show Diary").font(.headline).padding()
                        }
                    }
                } // Section
            } // Form
        } // VStack
        .onAppear {
            if self.framework.permission == .unknown {
                self.localStore.viewShown = "onboarding"
            }
        }
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
    static let localStore = LocalStore(userName: "Alice", testData: [EncountersWithUser.testData])

    static var previews: some View {
        ForEach(models, id: \.self) { name in ContentView().environmentObject(localStore)
            .environmentObject(ExposureFramework.shared)
            .previewDevice(PreviewDevice(rawValue: name))
            .previewDisplayName(name)
        }
    }
}
