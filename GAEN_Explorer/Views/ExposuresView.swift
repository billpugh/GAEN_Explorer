//
//  ExposuresView.swift
//
//  Created by Bill Pugh on 5/11/20.
//

import Foundation
import SwiftUI

struct ExposureDetailView: View {
    var day : BatchExposureInfo
    var info: CodableExposureInfo
    var body: some View {
        VStack {
            GeometryReader { geometry in
                Image("GAEN-Explorer").resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width * 0.5, height: geometry.size.width * 0.5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.black, lineWidth: 4))
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    Text("From batch \(day.userName) sent \(day.dateKeysSent, formatter: ExposureFramework.shared.dateTimeFr)")
                    Text("processed \(day.dateProcessed, formatter: ExposureFramework.shared.dateTimeFr)")
                    Text("memo: \(day.memo  ?? "")")
                    Text("")
                    Text("This exposure occurred on \(info.date, formatter: ExposureFramework.shared.dateFr)")
                    
                    Group { Text("The exposure lasted \(info.duration) minutes")
                        Text("The antenuationValue was \(info.attenuationValue) ")
                        Text("Transmission risk was \(info.transmissionRiskLevel)")
                        Text("total risk score is \(info.totalRiskScore)")
                        Text("")
                    }
                    Group {
                        Text("\(info.attenuationDurations[0]) minutes with  attenuation <= \(CodableExposureConfiguration.cutoff0)db")
                        Text("\(info.attenuationDurations[1]) minutes with \(CodableExposureConfiguration.cutoff0) < attenuation <= \(CodableExposureConfiguration.cutoff1)db")
                        Text("\(info.attenuationDurations[2]) minutes with \(CodableExposureConfiguration.cutoff1)db < attenuation")
                    }
                }

            }.padding(.horizontal)
        }
    }
}

struct ExposureInfoView: View {
    var day : BatchExposureInfo
    var info: CodableExposureInfo
    var width: CGFloat
    var body: some View {
        NavigationLink(destination: ExposureDetailView(day : day, info: info)) {
            HStack {
                Text("\(info.date, formatter: ExposureFramework.shared.dateFr)").frame(width: width / 5, alignment: .leading)
                Spacer()
                Text("\(info.duration)min").frame(width: width / 6, alignment: .trailing)
                Spacer()
                Text("\(info.transmissionRiskLevel) tRisk").frame(width: width / 5, alignment: .trailing)
                Spacer()
                Text("\(info.attenuationDurationsString)").frame(width: width / 4, alignment: .trailing)
            }
        }
    }
}

struct ExposuresView: View {
    @EnvironmentObject var localStore: LocalStore
    @State private var showingDeleteAlert = false
    @State private var showingSheet = false

    var body: some View {
        GeometryReader { geometry in
            VStack { List {
                ForEach(self.localStore.allExposures.reversed(), id: \.dateProcessed) { d in
                    Section(header: HStack { VStack {
                        Text("\(d.userName) sent \(d.dateKeysSent, formatter: ExposureFramework.shared.dateTimeFr)").font(.headline)
                        Text("recvd \(d.dateProcessed, formatter: ExposureFramework.shared.dateTimeFr)").font(.subheadline)

                        }
                        Spacer()
                        Text(d.memo ?? "")
                    }.padding(.vertical)) {
                        ForEach(d.exposures, id: \.id) { info in
                            ExposureInfoView(day : d, info: info, width: geometry.size.width)
                        }
                    }
                }
            } // forEach

            .sheet(isPresented: self.$showingSheet, onDismiss: { print("share sheet dismissed") },
                   content: {
                       ActivityView(activityItems: [
                           JsonItem(url: self.localStore.shareExposuresURL!,
                                    title: "Exposures for \(self.localStore.userName) from GAEN Explorer"),
                       ] as [Any], applicationActivities: nil, isPresented: self.$showingSheet)
            })

            // Erase button
            Button(action: { self.showingDeleteAlert = true }) {
                Text("Erase all exposures").foregroundColor(.red)

            }.alert(isPresented: self.$showingDeleteAlert) {
                Alert(title: Text("Really Erase all?"),
                      message: Text("Are you sure you want to delete the information on all of the exposures?"),
                      primaryButton: .destructive(Text("Delete")) { self.localStore.deleteAllExposures() },
                      secondaryButton: .cancel())
            } // Erase button
            }
        }
        .navigationBarTitle("Exposures for \(localStore.userName)", displayMode: .inline)
        .navigationBarItems(trailing:

            /// Export BUTTON
            Button(action: {
                print("Trying to share")
                self.localStore.exportExposuresToURL()
                self.showingSheet = true
                print("showingSheet set to true")
            }) {
                Image(systemName: "square.and.arrow.up")
            } // Export button
        )
    }
}

struct ExposuresView_Previews: PreviewProvider {
    static let models: [String] = ["iPhone SE", "iPhone 11 Pro Max"]
    static let localStore = LocalStore(userName: "Alice", transmissionRiskLevel: 6)

    static var previews: some View {
        NavigationView {
            ForEach(models, id: \.self) { name in ExposuresView().environmentObject(localStore)
                .environmentObject(ExposureFramework.shared)
                .previewDevice(PreviewDevice(rawValue: name))
                .previewDisplayName(name)
            }
        }
    }
}
