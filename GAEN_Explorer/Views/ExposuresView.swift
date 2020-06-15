//
//  ExposuresView.swift
//
//  Created by Bill Pugh on 5/11/20.
//

import Foundation
import SwiftUI

let thresholdDebug = true
struct ThresholdDataDebugView: View {
    let t: ThresholdData
    let width: CGFloat
    var body: some View {
        Text(t.description)
    }
}

struct ThresholdDataView: View {
    let t: ThresholdData
    let width: CGFloat
    var body: some View {
        HStack {
            Text(
                t.prevAttenuation > 0
                    ? "\(t.prevAttenuation) dB <  \(t.thisDurationString) min"
                    : "\(t.thisDurationString) min").frame(width: width / 2, alignment: .trailing)
            Text(t.attenuation < maxAttenuation ? "<= \(t.attenuation) dB" : "").frame(width: width / 4, alignment: .leading)
        }
    }
}

struct ExposureDurationViewLarge: View {
    let thresholdData: ThresholdData
    let maxDuration: Int
    static let scale: CGFloat = 4.5
    var body: some View {
        VStack {
            ZStack(alignment: .bottom) {
                if !thresholdData.cumulativeDuration.isExact {
                    Rectangle()
                        .fill(LinearGradient(gradient: Gradient(colors: [.red, .blue]), startPoint: .bottom, endPoint: .top))
                        .frame(width: 2.5 * ExposureDurationViewLarge.scale, height: CGFloat(maxDuration) * ExposureDurationViewLarge.scale)
                }

                Capsule()
                    .frame(width: 5 * ExposureDurationViewLarge.scale, height: CGFloat(thresholdData.cumulativeDuration.value) * ExposureDurationViewLarge.scale).foregroundColor(.primary)

                //                Capsule()
                //                    .frame(width: ExposureDurationViewLarge.scale, height: CGFloat(thresholdData.cumulativeDuration.value - thresholdData.prevCumulativeDuration.value) * ExposureDurationViewLarge.scale)
                //                    .offset(x: 0, y: CGFloat(-thresholdData.prevCumulativeDuration.value) * ExposureDurationViewLarge.scale).foregroundColor(.green).opacity(0.75)

                Capsule()
                    .frame(width: 5 * ExposureDurationViewLarge.scale, height: CGFloat(thresholdData.thisDuration.value) * ExposureDurationViewLarge.scale)
                    .offset(x: 0, y: CGFloat(thresholdData.thisDuration.value - thresholdData.cumulativeDuration.value) * ExposureDurationViewLarge.scale).foregroundColor(.green)
                //                Capsule()
                //                    .frame(width: ExposureDurationViewLarge.scale, height: CGFloat(thresholdData.maxThisDuration.value) * ExposureDurationViewLarge.scale)
                //                    .offset(x: 0, y: CGFloat(thresholdData.thisDuration.value - thresholdData.cumulativeDuration.value) * ExposureDurationViewLarge.scale).foregroundColor(.green).opacity(0.5)
            }.frame(height: CGFloat(maxDuration) * ExposureDurationViewLarge.scale, alignment: .bottom)
            Text(thresholdData.attenuationLabel)
        }.padding(.bottom, 8)
    }
}

struct BarView: View {
    let height: CGFloat
    let width: CGFloat
    let step: CGFloat
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 0))
            path.move(to: CGPoint(x: width, y: 0))
            for y in stride(from: 0, through: self.height, by: self.step) {
                path.move(to: CGPoint(x: 0, y: height - y))
                path.addLine(to: CGPoint(x: width, y: height - y))
            }
        }.stroke(Color.gray)
            .frame(width: width, height: height)
    }
}

struct ExposureDurationsViewLarge: View {
    let thresholdData: [ThresholdData]
    let maxDuration: Int
    var body: some View {
        ZStack(alignment: Alignment(horizontal: .center, vertical: .top)) {
            BarView(height: CGFloat(max(30, self.maxDuration)) * ExposureDurationViewLarge.scale,
                    width: ExposureDurationViewLarge.scale * 7 * CGFloat(thresholdData.count),
                    step: 10 * ExposureDurationViewLarge.scale)
            HStack(alignment: .bottom, spacing: 2 * ExposureDurationViewLarge.scale) {
                ForEach(thresholdData, id: \.self) {
                    ExposureDurationViewLarge(thresholdData: $0, maxDuration: max(30, self.maxDuration))
                }
            }
        }
    }
}

struct ExposureDurationViewSmall: View {
    let thresholdData: ThresholdData
    static let scale: CGFloat = 2
    var body: some View {
        ZStack(alignment: .bottom) {
            if thresholdData.capped {
                Rectangle()
                    .frame(width: 5 * ExposureDurationViewSmall.scale, height: CGFloat(thresholdData.cumulativeDurationCapped) * ExposureDurationViewSmall.scale / 2)
                    .offset(x: 0, y: -CGFloat(thresholdData.cumulativeDurationCapped) * ExposureDurationViewSmall.scale / 2).foregroundColor(.primary)
            }

            Capsule()
                .frame(width: 5 * ExposureDurationViewSmall.scale, height: CGFloat(thresholdData.cumulativeDurationCapped) * ExposureDurationViewSmall.scale).foregroundColor(.primary)

            if thresholdData.capped {
                Rectangle()
                    .frame(width: 5 * ExposureDurationViewSmall.scale, height: CGFloat(thresholdData.thisDurationCapped) * ExposureDurationViewSmall.scale / 2)
                    .offset(x: 0, y: CGFloat(-thresholdData.prevCumulativeDurationCapped) * ExposureDurationViewSmall.scale - CGFloat(thresholdData.thisDurationCapped) * ExposureDurationViewSmall.scale / 2).foregroundColor(.green)
            }
            Capsule()
                .frame(width: 5 * ExposureDurationViewSmall.scale, height: CGFloat(thresholdData.thisDurationCapped) * ExposureDurationViewSmall.scale)
                .offset(x: 0, y: CGFloat(-thresholdData.prevCumulativeDurationCapped) * ExposureDurationViewSmall.scale).foregroundColor(.green)

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
        }.frame(height: ExposureDurationViewSmall.scale * 30 + 10, alignment: .bottom)
    }
}

struct ExposureDetailViewDetail: View {
    var info: CodableExposureInfo
    let width: CGFloat
    @EnvironmentObject var localStore: LocalStore
    var body: some View {
        ForEach(self.info.thresholdData
            .filter { !($0.thisDuration == 0) },
                
            id: \.self) { t in
            ThresholdDataView(t: t, width: self.width)
        }
    }
}

struct ExposureDetailViewDebugDetail: View {
    var info: CodableExposureInfo
    let width: CGFloat
    @EnvironmentObject var localStore: LocalStore
    var body: some View {
        VStack {
            Text("minimum durations:")
            ForEach(self.info.thresholdData, id: \.self) { t in
                ThresholdDataDebugView(t: t, width: self.width)
            }

            Text("Raw analysis \(self.info.rawAnalysis.count):")
            ForEach(self.info.rawAnalysis, id: \.self) { ra in

                Text("\(ra.thresholds.description) \(ra.buckets.description)")
            }
        }
    }
}

struct ExposureDetailView: View {
    var batch: EncountersWithUser
    var info: CodableExposureInfo

    var line1: String {
        if let experiment = batch.experiment {
            return "Experiment \(date: experiment.started) - \(time: experiment.ended)"
        }
        return "From keys \(batch.userName) sent \(date: batch.dateKeysSent)"
    }

    var line2: String {
        if let _ = batch.experiment {
            return "Encounter with \(batch.userName)"
        }
        return "Analyzed \(batch.analysisPasses) times at \(date: batch.dateAnalyzed)"
    }

    @EnvironmentObject var localStore: LocalStore
    var body: some View { GeometryReader { geometry in
        VStack {
            ScrollView {
                ExposureDurationsViewLarge(thresholdData: self.info.thresholdData, maxDuration: self.info.calculatedTotalDuration.value).padding()
                VStack(alignment: .leading, spacing: 6) {
                    Text(self.line1)
                    Text(self.line2)

                    Spacer()
                    Text("This encounter occurred on \(self.info.date, formatter: dayFormatter)")
                    Group {
                        Text("encounter lasted  \(self.info.calculatedTotalDuration.description) minutes")
                        Text("meaningful duration: \(self.info.meaningfulDuration.description) minutes")
                        Spacer()

                    }.padding(.horizontal)

                    if thresholdDebug {
                        ExposureDetailViewDebugDetail(info: self.info, width: geometry.size.width)
                    } else {
                        ExposureDetailViewDetail(info: self.info, width: geometry.size.width)
                    }
                }
            }

        }.padding(.horizontal)
    }.navigationBarTitle("Encounter with \(batch.userName), \(self.info.date, formatter: dayFormatter)", displayMode: .inline)
    }
}

struct MeaningfulExposureView: View {
    var info: CodableExposureInfo
    var scale: Double = 3
    var value: Double {
        Double(info.meaningfulDuration.value)
    }

    static let maxValue: Double = 30
    let significant: Double = 15
    var maxSize: CGFloat {
        CGFloat(scale * Self.maxValue)
    }

    var scaledValue: CGFloat {
        CGFloat(scale * min(value, Self.maxValue))
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
                Text("\(info.date, formatter: dayFormatter)").frame(width: width / 6, alignment: .leading).padding()

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
                                        Text("\(d.userName) sent \(d.keysChecked) keys \(d.dateKeysSent, formatter: relativeDateFormatter)").font(.headline)

                                    }.padding(.top)
                                    HStack {
                                        Text(d.analysisPasses == 0 ? "not analyzed" : "analyzed \(d.dateAnalyzed, formatter: relativeDateFormatter), \(d.analysisPasses) \(d.analysisPasses == 1 ? "pass" : "passes") ")

                                    }.font(.subheadline).padding(.bottom, 8)

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

struct ExposureDetailView_Previews0: PreviewProvider {
    static let batch = EncountersWithUser.testData

    static var previews: some View {
        NavigationView {
            ExposureDetailView(batch: batch, info: batch.exposures[0])
        }.previewDevice(PreviewDevice(rawValue: "iPhone 11 Pro Max"))
    }
}

struct ExposureDetailView_Previews1: PreviewProvider {
    static let batch = EncountersWithUser.testData

    static var previews: some View {
        NavigationView {
            ExposureDetailView(batch: batch, info: batch.exposures[1])
        }.previewDevice(PreviewDevice(rawValue: "iPhone SE"))
    }
}

struct ExposuresView_Previews: PreviewProvider {
    static let localStore = LocalStore(userName: "Alice", testData: [EncountersWithUser.testData])

    static var previews: some View {
        NavigationView {
            ExposuresView()
        }.environmentObject(localStore)
            .environmentObject(ExposureFramework.shared)
            .previewDevice(PreviewDevice(rawValue: "iPhone 11 Pro Max"))
    }
}
