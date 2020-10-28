//
//  ContentView.swift
//  MacChuiChui
//
//  Created by Srun Zhou on 2020/7/10.
//  Copyright © 2020 Srun Zhou. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var bleViewModel:BleViewModel
    
    var body: some View {
        VStack {
            Text(bleViewModel.status)
            
            Text(bleViewModel.uuid)
            
            HStack{
                Spacer()
                
                Toggle(isOn: $bleViewModel.isScan) {
                           Text("Start scan")
                }.padding()
                
                Toggle(isOn: $bleViewModel.isSaveMoneyMode) {
                           Text("Save money?")
                }.padding()
                
                Spacer()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environmentObject(BleViewModel())
    }
}
