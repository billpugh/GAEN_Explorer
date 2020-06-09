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
                    Text("From keys \(self.batch.userName) sent \(self.batch.dateKeysSent, formatter: LocalStore.shared.shortDateFormatter)")
                    Text("analyzed \(self.batch.dateAnalyzed, formatter: LocalStore.shared.shortDateFormatter)")
                    Text("")
                    Text("This encounter occurred on \(self.info.date, formatter: LocalStore.shared.dayFormatter)")
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
    }.navigationBarTitle("Encounter with \(batch.userName)  \(self.info.date, formatter: LocalStore.shared.dayFormatter)", displayMode: .inline)
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
                Text("\(info.date, formatter: LocalStore.shared.dayFormatter)").frame(width: width / 5, alignment: .leading)
                Spacer()
                MeaningfulExposureView(info: info, scale: 2)
                Spacer()
                ExposureDurationsViewSmall(thresholdData: info.thresholdData)
            }
        }
    }
}

struct ExposureButton: View {
    let systemName: String
    let label: String
    let width: CGFloat
    var body: some View {
        VStack {
            Image(systemName: systemName)
            Text(label)
        }.frame(width: width)
    }
}

struct ExposuresView: View {
    @EnvironmentObject var localStore: LocalStore
    @State private var showingDeleteAlert = false
    @State private var exportingExposures = false

    @State private var showingSheet = false

    func makeAlert(
        title: String,
        message: String,
        destructiveButton: String,
        destructiveAction: @escaping () -> Void,
        cancelAction: @escaping () -> Void
    ) -> Alert {
        Alert(title: Text(title), message: Text(message),
              primaryButton: .destructive(Text(destructiveButton), action: destructiveAction),
              secondaryButton: .cancel(cancelAction))
    }

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                VStack {
                    List {
                        ForEach(self.localStore.allExposures.reversed(), id: \.userName) { d in
                            Section(header:
                                VStack(alignment: .leading) {
                                    HStack {
                                        Text("\(d.userName) sent \(d.keysChecked) keys \(d.dateKeysSent, formatter: LocalStore.shared.shortDateFormatter)").font(.headline)

                                    }.padding(.top)
                                    HStack {
                                        Text(d.analysisPasses == 0 ? "not analyzed" : "analyzed \(d.dateAnalyzed, formatter: LocalStore.shared.shortDateFormatter), \(d.analysisPasses) \(d.analysisPasses == 1 ? "pass" : "passes") ")

                                    }.font(.subheadline)

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
                                   ExposuresItem(url: self.localStore.shareExposuresURL!,
                                                 title: "Encounters for \(self.localStore.userName) from GAEN Explorer"),
                               ] as [Any], applicationActivities: nil, isPresented: self.$showingSheet)
                    })

                    HStack {
                        // Erase Analysis
                        Button(action: { LocalStore.shared.eraseAnalysis() })
                        { ExposureButton(systemName: "backward.end.alt", label: "reset", width: geometry.size.width * 0.23) }
                            .disabled(!self.localStore.canResetAnalysis).opacity(self.localStore.canResetAnalysis ? 1 : 0.5)

                        // Analyze
                        Button(action: { LocalStore.shared.analyze() }) { ExposureButton(systemName: "play", label: "analyze", width: geometry.size.width * 0.23) }
                            .disabled(!self.localStore.canAnalyze).opacity(self.localStore.canAnalyze ? 1 : 0.5)

                        // Delete all
                        Button(action: {
                            self.showingDeleteAlert = true
                        })
                        { ExposureButton(systemName: "trash", label: "erase", width: geometry.size.width * 0.23) }
                            .disabled(!self.localStore.canErase).opacity(self.localStore.canErase ? 1 : 0.5)
                            .alert(isPresented: self.$showingDeleteAlert) {
                                self.makeAlert(title: "Really Erase all?",
                                               message: "Are you sure you want to delete all keys and analysis?",
                                               destructiveButton: "Delete",
                                               destructiveAction: { self.localStore.deleteAllExposures()
                                                   self.showingDeleteAlert = false
                                               },
                                               cancelAction: { self.showingDeleteAlert = false })
                            }

                        Button(action: {
                            print("Trying to share")
                            self.exportingExposures = true
                            self.localStore.exportExposuresToURL()
                            self.showingSheet = true
                            self.exportingExposures = false
                            print("showingSheet set to true")
                       })
                        { ExposureButton(systemName: "square.and.arrow.up", label: "export", width: geometry.size.width * 0.23) }
                    }
                    // Erase button
//                Button(action: { self.showingDeleteAlert = true }) {
//                    Text("Erase all encounters").foregroundColor(.red)
//
//                }.alert(isPresented: self.$showingDeleteAlert) {
//                    Alert(title: Text("Really Erase all?"),
//                          message: Text("Are you sure you want to delete the information on all of the exposures?"),
//                          primaryButton: .destructive(Text("Delete")) { self.localStore.deleteAllExposures()
//                              self.showingDeleteAlert = false
//                          },
//                          secondaryButton: .cancel {
//                              self.showingDeleteAlert = false
//
//                            })
//                } // Erase button
                }
            }
            .navigationBarTitle(self.localStore.allExposures.count == 0 ?

                "No encounters for \(localStore.userName)" :
                "Encounters for \(localStore.userName)", displayMode: .inline)

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
