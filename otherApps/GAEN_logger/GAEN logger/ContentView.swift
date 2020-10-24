//
//  ContentView.swift
//  GAEN logger
//
//  Created by Bill on 6/1/20.
//  Copyright © 2020 NinjaMonkeyCoders. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var localState: LocalState
    var body: some View {
        ScrollView(.vertical) {
            VStack {
                if self.localState.all.isEmpty {
                    Text("No advertisements seen yet").frame(width: 450, alignment: .center)
                } else {
                    Button(action: { self.localState.dump() }) {
                        Text("Export")
                    }
                    Text("Active advertisers").frame(width: 450, alignment: .center)
                    HStack(spacing: 20) {
                        Text("        rssi          interval btwn pcks  ").frame(width: 450, alignment: .leading)
                        Text("    packet seen       ").frame(width: 290, alignment: .trailing)
                    }
                    HStack(spacing: 20) {
                        Text(" id  min .. max cnt     min..max     avg").frame(width: 450, alignment: .leading)
                        Text("first          last   ").frame(width: 290, alignment: .trailing)
                    }

                    ForEach(self.localState.all.filter { $0.recent }.sorted(by: { $0 < $1 }), id: \.peripheral) { d in
                        HStack(spacing: 20) {
                            Text("\(d.description)").frame(width: 450, alignment: .leading)
                            Text("\(d.time) .. \(d.lastTime)").frame(width: 290, alignment: .trailing)
                        }
                    }
                    if (!self.localState.all.filter { !$0.recent }.isEmpty) {
                        Divider()
                        Text("Inactive advertisers").frame(width: 450, alignment: .center)
                        HStack(spacing: 20) {
                            Text("        rssi          interval btwn pcks  ").frame(width: 450, alignment: .leading)
                            Text("    packet seen       ").frame(width: 290, alignment: .trailing)
                        }
                        HStack(spacing: 20) {
                            Text(" id  min .. max cnt     min..max     avg").frame(width: 450, alignment: .leading)
                            Text("first          last   ").frame(width: 290, alignment: .trailing)
                        }

                        ForEach(self.localState.all.filter { !$0.recent }.sorted(by: { $0 < $1 }), id: \.peripheral) { d in
                            HStack(spacing: 20) {
                                Text("\(d.description)").frame(width: 450, alignment: .leading)
                                Text("\(d.time) .. \(d.lastTime)").frame(width: 290, alignment: .trailing)
                            }
                        }
                    }
                }

            }.frame(maxWidth: 830)

        }.padding().font(.system(.body, design: .monospaced))
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environmentObject(LocalState.shared)
    }
}
