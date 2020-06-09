//
//  StartExperimentView.swift
//  GAEN_Explorer
//
//  Created by Bill on 6/7/20.
//  Copyright © 2020 Ninja Monkey Coders. All rights reserved.
//

import SwiftUI

struct ExperimentView: View {
    @EnvironmentObject var localStore: LocalStore
    @EnvironmentObject var framework: ExposureFramework

    @State var computingKeys = false
    @State var showingSheet = false
    @State var showingSheetToShareExposures = false
    @State var didExportExposures = false
    @State var didErase = false

    var finalButtonTitle: String {
        if !localStore.canAnalyze && localStore.allExposures.count > 0 {
            return "Share your analysis"
        } else if !localStore.canResetAnalysis {
            return "Analyze encounters"
        }
        return "Analyze again"
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
                        self.didErase = true
                        UIApplication.shared.open(URL(string: "App-prefs:root=Privacy")!)
                    }) { Text("Delete exposure Log") }.font(.title).padding(.vertical).disabled(didErase || framework.isEnabled)

                    if self.localStore.experimentStatus == .none {
                        Text("You have to go to Settings->Privacy->Health->COVID-19 Exposure Logging, scroll all the way down to the bottom, and then select the \"Delete Exposure Log\" button once (twice if it allows you to).").font(.subheadline)
                    }

                    Button(action: {
                        withAnimation {
                            self.localStore.startExperiment(self.framework)
                            self.didErase = false
                        }
                    }) { Text("Start scanning").font(.title) }.padding(.vertical).disabled(framework.isEnabled || !didErase)

                    if self.localStore.experimentStatus == .none {
                        Text("This will resume exposure scanning and start the experiment.")
                    }
                }.disabled(self.localStore.experimentStatus != .none)

                // MARK: started

                Group {
                    Button(action: {
                        withAnimation {
                            self.framework.isEnabled = false
                            self.localStore.experimentEnded = Date()
                        }
                    }) { Text("End scanning").font(.title) }.padding(.vertical)

                    if self.localStore.experimentStatus != .completed {
                        Text("When it is time to end the experiment, everyone should stop scanning together")
                    }

                }.disabled(self.localStore.experimentStatus != .started)

                // MARK: completed

                Group {
                    Button(action: { self.computingKeys = true
                        self.localStore.getAndPackageKeys { success in
                            print("getAndPackageKeys done")
                            if success {
                                self.showingSheet = true
                                LocalStore.shared.addDiaryEntry(.keysShared)
                            }
                            self.computingKeys = false
                        }
                    }) { Text("Share keys") }
                        .font(.title).padding(.vertical)

                    if self.localStore.experimentStatus == .completed {
                        Text(self.localStore.allExposures.count == 0 ? "You currently don't have keys from anyone else"
                            : "You currently have keys from \(self.localStore.allExposures.count) other people. When you share keys with someone, you share your keys and everyone elses. When everyone has all the keys, analyze your encounters")
                    }

                    Button(action: {
                        withAnimation {
                            if self.localStore.canAnalyze {
                                LocalStore.shared.analyze()
                            } else {
                                self.localStore.exportExposuresToURL()
                                self.showingSheetToShareExposures = true
                                self.showingSheet = true
                                self.didExportExposures = true
                                print("showingSheet set to true")
                            }
                        }
                    }
                    ) { Text(finalButtonTitle).font(.title) }
                        .padding(.vertical)
                        .disabled(self.localStore.allExposures.count == 0)

                }.disabled(self.localStore.experimentStatus != .completed)

                // MARK: End/Abort

                Button(action: {
                    self.localStore.experimentStarted = nil
                    self.localStore.experimentEnded = nil
                    self.localStore.viewShown = nil
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
    static var previews: some View {
        NavigationView {
            ExperimentView().environmentObject(LocalStore.shared)
        }
    }
}
