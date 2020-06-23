//
//  StartExperimentView.swift
//  GAEN_Explorer
//
//  Created by Bill on 6/7/20.
//  Copyright © 2020 Ninja Monkey Coders. All rights reserved.
//

import SwiftUI

func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

struct ExperimentView: View {
    @EnvironmentObject var localStore: LocalStore
    @EnvironmentObject var framework: ExposureFramework

    @State var computingKeys = false
    @State var showingSheet = false
    @State var showingSheetToShareExposures = false
    @State var didExportExposures = false
    @State var lastMemo = ""

    var analysisButtonTitle: String {
        if localStore.experimentStatus != .completed {
            return "Perform analysis"
        }
        if localStore.allExposures.count == 0 {
            return "No keys to analyze"
        }
        if !localStore.canAnalyze {
            return "Share your analysis"
        }
        return "Perform analysis \(numberAnalysisPasses - localStore.analysisPassedCompleted) times"
    }

    func itemsToShare() -> [Any] {
        if showingSheetToShareExposures {
            return [ExposuresItem(url: localStore.shareExposuresURL!,
                                  title: "Encounters for \(localStore.userName) from GAEN Explorer")]
        }
        return DiagnosisKeyItem(framework.keyCount,
                                localStore.userName,
                                framework.keyURL!).itemsToShare()
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack {
                HStack {
                    Text("Description:").font(.headline)
                    TextField("description", text: self.$localStore.experimentDescription)
                }

                // MARK: experimentStatus == .none

                Group {
                    Button(action: {
                        withAnimation {
                            self.framework.isEnabled = false
                        }
                    }) { Text("Turn off exposure scanning") }.font(.title).padding(.vertical).disabled(!framework.isEnabled)

                    if self.localStore.experimentStatus == .none {
                        Text("This will turn off scanning and broadcasting of Bluetooth advertisements so we can get a clean start")
                    }

                    Button(action: {
                        hideKeyboard()
                        self.framework.eraseExposureLogs()
                    }) { Text("Delete exposure Log") }.font(.title).padding(.vertical).disabled(framework.exposureLogsErased || framework.isEnabled)

                    if self.localStore.experimentStatus == .none {
                        Text("You have to go to Settings->Privacy->Health->COVID-19 Exposure Logging, scroll all the way down to the bottom, and then select the \"Delete Exposure Log\" button once (twice if it allows you to).").font(.subheadline)
                    }

                    Button(action: {
                        withAnimation {
                            hideKeyboard()
                            self.localStore.startExperiment(self.framework)
                            self.didExportExposures = false
                        }
                    }) { Text("Start scanning").font(.title) }.padding(.vertical).disabled(framework.isEnabled || !framework.exposureLogsErased)

                    if self.localStore.experimentStatus == .none {
                        Text("This will resume exposure scanning and start the experiment.")
                    }
                }.disabled(self.localStore.experimentStatus != .none)

                // MARK: started

                HStack(alignment: .bottom) {
                    Button(action: {
                        self.localStore.addDiaryEntry(.memo, self.lastMemo)

                        withAnimation {
                            self.lastMemo = ""
                        }
                                                    })
                    { Text("Add memo") }.font(.title).padding(.leading)
                    TextField("memo", text: self.$lastMemo)
                }
                .disabled(self.localStore.experimentStatus == .none)

                Group {
                    Button(action: {
                        withAnimation {
                            hideKeyboard()
                            self.localStore.endScanningForExperiment(self.framework)
                        }
                    }) { Text("End scanning").font(.title) }.padding(.vertical)

                    if self.localStore.experimentStatus != .completed {
                        Text("When it is time to end the experiment, everyone should stop scanning together")
                    }

                }.disabled(self.localStore.experimentStatus != .started)

                // MARK: completed

                Group {
                    Button(action: { self.computingKeys = true
                        self.localStore.getAndPackageKeys { url in
                            print("getAndPackageKeys done")
                            if url != nil {
                                self.showingSheet = true
                                LocalStore.shared.addDiaryEntry(.keysShared)
                            }
                            self.computingKeys = false
                        }
                    }) { Text("Share keys") }
                        .font(.title).padding(.vertical)

                    if self.localStore.experimentStatus == .completed && (self.localStore.allExposures.count == 0 || localStore.canAnalyze) {
                        Text(self.localStore.allExposures.count == 0 ? "You currently don't have keys from anyone else"
                            : "You currently have keys from \(self.localStore.allExposures.count) other people. When you share keys with someone, you share your keys and all the ones you have already received.")
                    }

                    Button(action: {
                        withAnimation {
                            if self.localStore.canAnalyze {
                                LocalStore.shared.analyze(parameters: AnalysisParameters(doMaxAnalysis: true))
                            } else {
                                self.localStore.exportExposuresToURL()
                                self.showingSheetToShareExposures = true
                                self.showingSheet = true
                                self.didExportExposures = true
                                print("showingSheet set to true")
                            }
                        }
                    }
                    ) { Text(analysisButtonTitle).font(.title) }
                        .padding(.vertical)
                        .disabled(self.localStore.allExposures.count == 0)

                }.disabled(self.localStore.experimentStatus != .completed)

                // MARK: End/Abort

                Button(action: {
                    self.localStore.resetExperiment(self.framework)
                    self.didExportExposures = false
                }) {
                    Text(self.localStore.experimentStatus == .completed && self.didExportExposures ? "End experiment" : "Abort experiment").font(.title)
                }
                .padding(.vertical)
                .disabled(self.localStore.experimentStatus == .none)

            }.sheet(isPresented: $showingSheet,
                    onDismiss: { self.showingSheetToShareExposures = false },
                    content: {
                        ActivityView(activityItems: self.itemsToShare(),
                                     applicationActivities: nil, isPresented: self.$showingSheet)
            })
        }
        .padding().navigationBarTitle(Text(localStore.experimentMessage ?? "Start experiment"), displayMode: .inline)
    }
}

struct StartExperimentView_Previews: PreviewProvider {
    static let localStore = LocalStore(userName: "Alice", testData: [EncountersWithUser.testData])
    static var previews: some View {
        NavigationView {
            ExperimentView().environmentObject(localStore)
                .environmentObject(ExposureFramework.shared)
        }
    }
}
