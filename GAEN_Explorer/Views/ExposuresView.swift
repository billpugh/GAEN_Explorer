//
//  ExposuresView.swift
//
//  Created by Bill Pugh on 5/11/20.
//

import Foundation
import SwiftUI

struct ThresholdDataView: View {
    let t: ThresholdData
    let width: CGFloat
    var body: some View {
        HStack {
            Text(
                t.prevAttenuation > 0 ? "\(t.prevAttenuation)dB" : "").frame(width: width / 4, alignment: .trailing)
            Text(t.prevAttenuation > 0 ? " < \(t.thisDuration) min" : "\(t.thisDuration) min").frame(width: width / 4.5, alignment: .trailing)
            Text(t.attenuation < 90 ? "<= \(t.attenuation)dB" : "").frame(width: width / 4, alignment: .leading)
        }
    }
}

struct ExposureDurationViewLarge: View {
    let thresholdData: ThresholdData
    let scale: CGFloat = 6
    let cornerRadius: CGFloat = 2
    var body: some View {
        VStack {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: cornerRadius * scale)
                    .frame(width: 5 * scale, height: CGFloat(thresholdData.cumulativeDuration) * scale).foregroundColor(.primary)
                RoundedRectangle(cornerRadius: cornerRadius * scale)
                    .frame(width: 5 * scale, height: CGFloat(thresholdData.thisDuration) * scale)
                    .offset(x: 0, y: CGFloat(-thresholdData.prevDuration) * scale).foregroundColor(.green)
            }
            Text(thresholdData.attenuationLabel)
        }.padding(.bottom, 8)
    }
}

struct ExposureDurationsViewLarge: View {
    let thresholdData: [ThresholdData]
    var body: some View {
        HStack(alignment: .bottom) {
            ForEach(thresholdData, id: \.self) {
                ExposureDurationViewLarge(thresholdData: $0)
            }
        }
    }
}

struct ExposureDurationViewSmall: View {
    let thresholdData: ThresholdData
    let scale: CGFloat = 2
    let cornerRadius: CGFloat = 2
    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: cornerRadius * scale)
                .frame(width: 5 * scale, height: CGFloat(thresholdData.cumulativeDuration) * scale).foregroundColor(.primary)
            RoundedRectangle(cornerRadius: cornerRadius * scale)
                .frame(width: 5 * scale, height: CGFloat(thresholdData.thisDuration) * scale)
                .offset(x: 0, y: CGFloat(-thresholdData.prevDuration) * scale).foregroundColor(.green)

        }.padding(.bottom, 8)
    }
}

struct ExposureDurationsViewSmall: View {
    let thresholdData: [ThresholdData]
    var body: some View {
        HStack(alignment: .bottom) {
            ForEach(thresholdData, id: \.self) {
                ExposureDurationViewSmall(thresholdData: $0)
            }
        }
    }
}

struct ExposureDetailView: View {
    var batch: EncountersWithUser
    var info: CodableExposureInfo
    @EnvironmentObject var localStore: LocalStore
    var body: some View { VStack {
        ExposureDurationsViewLarge(thresholdData: self.info.thresholdData).padding(.vertical)
        ScrollView {
            GeometryReader { geometry in
                VStack(alignment: .leading, spacing: 6) {
                    Text("From keys \(self.batch.userName) sent \(self.batch.dateKeysSent, formatter: ExposureFramework.shared.shortDateFormatter)")
                    Text("analyzed \(self.batch.dateAnalyzed, formatter: ExposureFramework.shared.shortDateFormatter)")
                    Text("")
                    Text("This encounter occurred on \(self.info.date, formatter: ExposureFramework.shared.dayFormatter)")
                    Group {
                        Text("encounter lasted \(self.info.duration)/\(self.info.extendedDuration) minutes")
                        Text("meaningful duration: \(self.info.meaningfulDuration) minutes")

                        Text("durations at different attenuations:").padding(.top)
                    }
                    ForEach(self.info.thresholdData
                        .filter { $0.thisDuration > 0 },
                            id: \.self) { t in
                        ThresholdDataView(t: t, width: geometry.size.width)
                    }
                }
            }

        }.padding(.horizontal)
    }.navigationBarTitle("Encounter with \(batch.userName)  \(self.info.date, formatter: ExposureFramework.shared.dayFormatter)", displayMode: .inline)
    }
}

struct MeaningfulExposureView: View {
    var info: CodableExposureInfo
    var scale: Double = 3
    var value: Double {
        Double(info.meaningfulDuration)
    }

    static let maxValue: Double = 30
    let significant: Double = 15
    var maxSize: CGFloat {
        CGFloat(scale * Self.maxValue)
    }

    var scaledValue: CGFloat {
        CGFloat(scale * value)
    }

    var scaledSignificant: CGFloat {
        CGFloat(scale * significant)
    }

    var hue: Double {
        if value > significant {
            return 0
        }
        return ((significant - value) / significant).squareRoot() * 0.3
    }

    var body: some View {
        ZStack {
            Circle().fill(Color(hue: hue, saturation: 1, brightness: 1)).frame(width: scaledValue, height: scaledValue)
            Circle().stroke(Color.primary, lineWidth: CGFloat(scale * (value >= significant ? 2.0 : 0.5))).frame(width: scaledSignificant, height: scaledSignificant)

        }.frame(width: maxSize, height: maxSize)
    }
}

struct ExposureInfoView: View {
    var day: EncountersWithUser
    var info: CodableExposureInfo
    var width: CGFloat
    var body: some View {
        NavigationLink(destination: ExposureDetailView(batch: day, info: info)) {
            HStack {
                Text("\(info.date, formatter: ExposureFramework.shared.dayFormatter)").frame(width: width / 5, alignment: .leading)
                Spacer()
                MeaningfulExposureView(info: info, scale: 2)
                Spacer()
                ExposureDurationsViewSmall(thresholdData: info.thresholdData)
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
                    ForEach(self.localStore.allExposures.reversed(), id: \.userName) { d in
                        Section(header:
                            VStack(alignment: .leading) {
                                HStack {
                                    Text("\(d.userName) sent \(d.keysChecked) keys \(d.dateKeysSent, formatter: ExposureFramework.shared.shortDateFormatter)").font(.headline)

                                }.padding(.top)
                                HStack {
                                    Text("  analyzed \(d.dateAnalyzed, formatter: ExposureFramework.shared.shortDateFormatter), \(d.analysisPasses) \(d.analysisPasses == 1 ? "pass" : "passes") ")

                                }.font(.subheadline).padding(.bottom)

//                                HStack {
//                                    Text("Date").frame(width: geometry.size.width / 5, alignment: .leading)
//
//                                    Text("Duration").frame(width: geometry.size.width / 6, alignment: .trailing)
//
//                                    Text("Trans risk").frame(width: geometry.size.width / 5, alignment: .trailing)
//
//                                    Text("durations").frame(width: geometry.size.width / 4, alignment: .trailing)
//                                }.padding(.vertical, 5).font(.footnote)
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
                                        title: "Encounters for \(self.localStore.userName) from GAEN Explorer"),
                           ] as [Any], applicationActivities: nil, isPresented: self.$showingSheet)
                    })

                // Erase button
                Button(action: { self.showingDeleteAlert = true }) {
                    Text("Erase all encounters").foregroundColor(.red)

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
            .navigationBarTitle(self.localStore.allExposures.count == 0 ?

                "No encounters for \(localStore.userName)" :
                "Encounters for \(localStore.userName)", displayMode: .inline)
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
    static let batch = EncountersWithUser.testData

    static var previews: some View {
        NavigationView {
            ExposureDetailView(batch: batch, info: batch.exposures[0])
        }
    }
}

struct ExposuresView_Previews: PreviewProvider {
    static let localStore = LocalStore(userName: "Alice", testData: [EncountersWithUser.testData])

    static var previews: some View {
        NavigationView {
            ExposuresView().environmentObject(localStore)
                .environmentObject(ExposureFramework.shared)
        }
    }
}
