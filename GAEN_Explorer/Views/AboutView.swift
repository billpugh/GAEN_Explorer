//
//  AboutView.swift
//
//  Created by Bill Pugh on 5/11/20.
//

import Foundation
import SwiftUI

struct GAENExplorerImage: View {
    var width: CGFloat
    var body: some View {
        Image("GAEN-Explorer").resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: width)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black, lineWidth: 2))
    }
}

struct MyAboutView: View {
    @EnvironmentObject var localStore: LocalStore
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    VStack(spacing: 15) {
                        GAENExplorerImage(width: geometry.size.width * 0.25)
                            .alignmentGuide(.leading) { _ in -geometry.size.width * 0.25 }

                        Group {
                            Text("Not to be used for actual reporting of COVID-19").font(.subheadline)
                            Text("Version \(self.localStore.version), build \(self.localStore.build)").font(.subheadline)
                            Text("""
                            The Google Apple Exposure Notification Framework is designed to allow the use of Bluetooth in a privacy preserving way to detect close encounters with other smartphones also using the protocol, and if one of those people later reports and verifies a positive diagnosis for COVID-19, allow people they were in contact with to be notified that they were exposed.
                            """)
                            Button(action: {
                                UIApplication.shared.open(URL(string: "https://www.google.com/covid19/exposurenotifications/")!)
                        }) { Text("Exposure Notification framework").font(.footnote) }
                        }
                        Text("""
                        This app, GAEN Explorer, allows evaluation of the ability of the framework to accurately detect close encounters, and assists in defining the parameters used by a GAEN app to which encounters should be reported, and compare that with the encounters should be reported, which might be defined by a public health authority as 15 or more minutes within 6 feet.
                        """)

                        Button(action: {
                            UIApplication.shared.open(URL(string: "https://github.com/billpugh/GAEN_Explorer")!)
                        }) { Text("https://github.com/billpugh/GAEN_Explorer").font(.footnote) }
                        Text("""
                        This app is not intended nor suitable for dealing with actual reports of a diganosis of COVID-19. All information is kept private to the app and other devices participating in experiments.
                        """).font(.footnote)
                        Text("You must have the special entitlements that Apple is giving out in order to be able to run this code, and they are only giving out those entitlements to developers working with public health organizations. I can't help you get those entitlements. ").font(.footnote)

                    }.padding(.horizontal)
                }
            }
            .navigationBarTitle("About GAEN Explorer", displayMode: .inline)
        }
    }
}

struct MyAboutView_Previews: PreviewProvider {
    static let models: [String] = ["iPhone SE", "iPhone 11 Pro Max"]
    static var previews: some View {
        ForEach(models, id: \.self) { name in
            NavigationView { MyAboutView() }.environmentObject(LocalStore.shared)
                .previewDevice(PreviewDevice(rawValue: name))
                .previewDisplayName(name)
        }
    }
}
