//
//  ExposuresView.swift
//
//  Created by Bill Pugh on 5/11/20.
//

import Foundation
import SwiftUI

struct ExposureDetailView: View {
    var batch: BatchExposureInfo
    var info: CodableExposureInfo
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Image("GAEN-Explorer").resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width * 0.5, height: geometry.size.width * 0.5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.black, lineWidth: 2))
                    .padding()

                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("From batch \(self.batch.userName) sent \(self.batch.dateKeysSent, formatter: ExposureFramework.shared.shortDateFormatter)")
                        Text("processed \(self.batch.dateProcessed, formatter: ExposureFramework.shared.shortDateFormatter)")
                        Text("\(self.batch.memoConfig)")
                        Text("")
                        Text("This exposure occurred on \(self.info.date, formatter: ExposureFramework.shared.dayFormatter)")

                        Group { Text("The exposure lasted \(self.info.duration) minutes")
                            Text("The antenuationValue was \(self.info.attenuationValue) ")
                            Text("Transmission risk was \(self.info.transmissionRiskLevel)")
                            Text("total risk score is \(self.info.totalRiskScore)")
                            Text("")
                        }
                        Group {
                            Text("\(self.info.attenuationDurations[0]) minutes with  attenuation <= \(self.batch.someConfig.attenuationDurationThresholds[0])db")
                            Text("\(self.info.attenuationDurations[1]) minutes with \(self.batch.someConfig.attenuationDurationThresholds[0]) < attenuation <= \(self.batch.someConfig.attenuationDurationThresholds[1])db")
                            Text("\(self.info.attenuationDurations[2]) minutes with \(self.batch.someConfig.attenuationDurationThresholds[1])db < attenuation")
                        }
                    }

                }.padding(.horizontal)
            }.navigationBarTitle("Exposure details", displayMode: .inline)
        }
    }
}

struct ExposureInfoView: View {
    var day: BatchExposureInfo
    var info: CodableExposureInfo
    var width: CGFloat
    var body: some View {
        NavigationLink(destination: ExposureDetailView(batch: day, info: info)) {
            HStack {
                Text("\(info.date, formatter: ExposureFramework.shared.dayFormatter)").frame(width: width / 5, alignment: .leading)

                Text("\(info.duration)min").frame(width: width / 6, alignment: .trailing)

                Text("\(info.transmissionRiskLevel)").frame(width: width / 5, alignment: .trailing)

                Text("\(info.attenuationDurationsString)").frame(width: width / 4, alignment: .trailing)
            }
        }
    }
}

struct ExposuresView: View {
    @EnvironmentObject var localStore: LocalStore
    @State private var showingDeleteAlert = false
    @State private var exportingExposures = false

    @State private var showingSheet = false

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                VStack { List {
                    ForEach(self.localStore.allExposures.reversed(), id: \.dateProcessed) { d in
                        Section(header:
                            VStack(alignment: .leading) {
                                HStack {
                                    VStack {
                                        Text("\(d.userName) sent \(d.dateKeysSent, formatter: ExposureFramework.shared.shortDateFormatter)").font(.headline)
                                        Text("processed \(d.dateProcessed, formatter: ExposureFramework.shared.shortDateFormatter)").font(.subheadline)
                                    }
                                    Spacer()
                                    Text(d.shortMemoConfig)
                                }.padding(.vertical, 8)
                                HStack {
                                    Text("Date").frame(width: geometry.size.width / 5, alignment: .leading)

                                    Text("Duration").frame(width: geometry.size.width / 6, alignment: .trailing)

                                    Text("Trans risk").frame(width: geometry.size.width / 5, alignment: .trailing)

                                    Text("durations").frame(width: geometry.size.width / 4, alignment: .trailing)
                                }.padding(.bottom, 5).font(.footnote)
                        }) {
                            ForEach(d.exposures, id: \.id) { info in
                                ExposureInfoView(day: d, info: info, width: geometry.size.width)
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
                          primaryButton: .destructive(Text("Delete")) { self.localStore.deleteAllExposures()
                              self.showingDeleteAlert = false
                          },
                          secondaryButton: .cancel {
                              self.showingDeleteAlert = false

                    })
                } // Erase button
                }
            }
            .navigationBarTitle("Exposures for \(localStore.userName)", displayMode: .inline)
            .navigationBarItems(trailing:

                /// Export BUTTON
                Button(action: {
                    print("Trying to share")
                    self.exportingExposures = true
                    self.localStore.exportExposuresToURL()
                    self.showingSheet = true
                    self.exportingExposures = false
                    print("showingSheet set to true")
            }) {
                    Image(systemName: "square.and.arrow.up")
                } // Export button
            )
            ActivityIndicatorView(isAnimating: $exportingExposures)
        }
    }
}

struct ExposureDetailView_Previews: PreviewProvider {
    static let batch = BatchExposureInfo.testData

    static var previews: some View {
        NavigationView {
            ExposureDetailView(batch: batch, info: batch.exposures[0])
        }
    }
}

struct ExposuresView_Previews: PreviewProvider {
    static let localStore = LocalStore(userName: "Alice", transmissionRiskLevel: 6, testData: [BatchExposureInfo.testData])

    static var previews: some View {
        NavigationView {
            ExposuresView().environmentObject(localStore)
                .environmentObject(ExposureFramework.shared)
        }
    }
}
