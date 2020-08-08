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
                HStack(spacing: 20) {
                    Text(" id     rssi    cnt     interval     avg").frame(width: 450, alignment: .leading)
                    Text("first          last   ").frame(width: 290, alignment: .trailing)
                }

                ForEach(self.localState.all.filter { $0.recent }.sorted(by: { $0 < $1 }), id: \.peripheral) { d in
                    HStack(spacing: 20) {
                        Text("\(d.description)").frame(width: 450, alignment: .leading)
                        Text("\(d.time) .. \(d.lastTime)").frame(width: 290, alignment: .trailing)
                    }
                }
                Divider()
                ForEach(self.localState.all.filter { !$0.recent }.sorted(by: { $0 < $1 }), id: \.peripheral) { d in
                    HStack(spacing: 20) {
                        Text("\(d.description)").frame(width: 450, alignment: .leading)
                        Text("\(d.time) .. \(d.lastTime)").frame(width: 290, alignment: .trailing)
                    }
                }

            }.padding().font(.system(.body, design: .monospaced))

        }.frame(maxWidth: 830)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environmentObject(LocalState.shared)
    }
}
