//
//  AboutView.swift
//
//  Created by Bill Pugh on 5/11/20.
//

import Foundation
import SwiftUI

struct MyAboutView: View {
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 15) {
                    Image("GAEN-Explorer").resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width * 0.5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.black, lineWidth: 2))

                    Text("Not to be used for actual reporting of COVID-19").font(.subheadline)
                    Text("No information is sent to any server. You need to exchange keys by sharing them via airdrop or email").font(.subheadline).padding(.horizontal)
                    Text("This app is designed to allow you to experiment with the Google/Apple Exposure Notification (GAEN) framework. Even without looking inside the code, you can can have several people install the app on their phone, go through an encounter, and then exchange diagnosis keys and find out the charactertistics of the encounters that were reported by the framework. If you want to use this app, it is very helpful if you understand how the framework works (e.g., you know what a diagnosis key is).")

                    Button(action: {
                        UIApplication.shared.open(URL(string: "https://github.com/billpugh/GAEN_Explorer")!)
                }) { Text("https://github.com/billpugh/GAEN_Explorer").font(.footnote) }

                    Text("You must have the special entitlements that Apple is giving out in order to be able to run this code, and they are only giving out those entitlements to developers working with public health organizations. I can't help you get those entitlements. The app uses a special entitlement that allows it to get the diagnosis key for the current day.").font(.footnote)

                }.padding(.all)
            }
        }
        .navigationBarTitle("About GAEN Explorer", displayMode: .inline)
    }
}

struct MyAboutView_Previews: PreviewProvider {
    static let models: [String] = ["iPhone SE", "iPhone 11 Pro Max"]
    static var previews: some View {
        ForEach(models, id: \.self) { name in
            NavigationView { MyAboutView() }
                .previewDevice(PreviewDevice(rawValue: name))
                .previewDisplayName(name)
        }
    }
}
