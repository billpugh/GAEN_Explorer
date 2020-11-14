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
    @State private var document: ExportDocument = ExportDocument(content: ["Hello, World!"])
    let leftWidth: CGFloat = 540
    
    let rightWidth: CGFloat = 250
    @State private var isExporting: Bool = false
    var body: some View {
        ScrollView(.vertical) {
            VStack {
                if self.localState.all.isEmpty {
                    Text("No advertisements seen yet").frame(width: leftWidth + rightWidth, alignment: .center)
                } else {
                    Button(action: { document = ExportDocument(content: self.localState.export())
                                                               isExporting = true
                     }) {
                        Text("Export")
                    }
                    Text("\(self.localState.all.filter { $0.recent }.count) Active advertisers").frame(width: leftWidth + rightWidth, alignment: .center)
                    HStack(spacing: 20) {
                        Text("        rssi     pkt   pkts  seen for").frame(width: leftWidth, alignment: .leading)
                        Text("    packet seen       ").frame(width: rightWidth, alignment: .trailing)
                    }
                    HStack(spacing: 20) {
                        Text(" id  min .. max  cnt   /min   seconds").frame(width: leftWidth, alignment: .leading)
                        Text("first          last   ").frame(width: rightWidth, alignment: .trailing)
                    }

                    ForEach(self.localState.all.filter { $0.recent }.sorted(by: { $0 < $1 }), id: \.peripheral) { d in
                        HStack(spacing: 20) {
                            Text("\(d.description)").frame(width: leftWidth, alignment: .leading)
                            Text("\(d.time) .. \(d.lastTime)").frame(width: rightWidth, alignment: .trailing)
                        }
                    }
                    if (!self.localState.all.filter { !$0.recent }.isEmpty) {
                        Divider()
                        Text("\(self.localState.all.filter { !$0.recent }.count) Inactive advertisers").frame(width: leftWidth + rightWidth, alignment: .center)
                        HStack(spacing: 20) {
                            Text("        rssi     pkt   pkts  seen for").frame(width: leftWidth, alignment: .leading)
                            Text("    packet seen       ").frame(width: rightWidth, alignment: .trailing)
                        }
                        HStack(spacing: 20) {
                            Text(" id  min .. max  cnt   /min   seconds").frame(width: leftWidth, alignment: .leading)
                            Text("first          last   ").frame(width: rightWidth, alignment: .trailing)
                        }

                        ForEach(self.localState.all.filter { !$0.recent }.sorted(by: { $0 < $1 }), id: \.peripheral) { d in
                            HStack(spacing: 20) {
                                Text("\(d.description)").frame(width: leftWidth, alignment: .leading)
                                Text("\(d.time) .. \(d.lastTime)").frame(width: rightWidth, alignment: .trailing)
                            }
                        }
                    }
                }

            }.frame(maxWidth: leftWidth+30+rightWidth)
            .fileExporter(
                 isPresented: $isExporting,
                 document: document,
                 contentType: .commaSeparatedText,
                 defaultFilename: "gaenLog.csv"
             ) { result in
                 if case .success = result {
                     print("Export success")
                 } else {
                    print("Export success")
                 }
             }

        }.padding().font(.system(.body, design: .monospaced))
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environmentObject(LocalState.shared)
    }
}
