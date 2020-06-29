//
//  OnboardingView.swift
//  GAEN_Explorer
//
//  Created by Bill on 6/28/20.
//  Copyright © 2020 Ninja Monkey Coders. All rights reserved.
//

import CoreMotion
import ExposureNotification
import SwiftUI

class PermissionsStatus: NSObject, ObservableObject {
    var motionPermission: CMAuthorizationStatus {
        CMMotionActivityManager.authorizationStatus()
    }

    func didChange() {
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }

    func requestMotionPermission() {
        SensorFusion.shared.requestMotionPermission {
            self.didChange()
        }
    }
}

struct CheckView: View {
    let checked: Bool
    let label: String
    let action: () -> Void
    var body: some View {
        HStack {
            Image(systemName: checked ? "checkmark.square" : "square")
            Button(action: action) { Text(label) }.disabled(checked)
        }
    }
}

struct OnboardingView: View {
    @EnvironmentObject var localStore: LocalStore
    let permissionsStatus = PermissionsStatus()
    var body: some View {
        GeometryReader { geometry in

            VStack(spacing: 15) {
                GAENExplorerImage(width: geometry.size.width * 0.25)
                    .alignmentGuide(.leading) { _ in -geometry.size.width * 0.25 }

                VStack(alignment: .leading, spacing: 15) {
                    NavigationLink(destination: MyAboutView()) {
                        Text("About GAEN Explorer").font(.headline)
                    }
                    Text("""
                    Welcome to GAEN Explorer. Before you can get started measuring how encounters are detected by GAEN, you need to give the app several permissions:
                    """)

                    Form {
                        Section(header: Text("Essential").font(.title).padding(.top)) {
                            CheckView(checked: ExposureFramework.shared.permission == .authorized, label: "Use Exposure Notification framework") {
                                ExposureFramework.shared.requestENPermission()
                            }.padding(.vertical)
                        }

                        Section(header: Text("For Experiments").font(.title)) {
                            CheckView(checked: self.localStore.userNotificationAuthorization == .authorized, label: "Notification when experiment ends") {
                                self.localStore.requestNotificationPermission()
                            }.padding(.vertical)
                            CheckView(checked: self.permissionsStatus.motionPermission == .authorized,
                                      label: "Track movements during experiment") {
                                self.permissionsStatus.requestMotionPermission()
                            }.padding(.vertical)
                        }
                    }
                }
            }.padding()

        }.navigationBarTitle("Welcome to GAEN Explorer", displayMode: .inline)
            .navigationBarBackButtonHidden(ExposureFramework.shared.permission != .authorized)
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static let localStore = LocalStore(userName: "Alice", testData: [EncountersWithUser.testData])

    static var previews: some View {
        NavigationView { OnboardingView() }.environmentObject(localStore)
    }
}
