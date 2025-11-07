//
//  EntranceView.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/11/3.
//

import SwiftUI

struct EntranceView: View {
    @StateObject private var viewModel = EntranceViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Image("logo")
                
                TextField("输入频道名称", text: $viewModel.channelName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    .frame(width: 250, height: 50)
                    .disabled(viewModel.isLoading)
                
                Button(action: viewModel.call) {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text(viewModel.isLoading ? "连接中..." : "Start")
                            .foregroundColor(.white)
                    }
                    .frame(width: 250, height: 50)
                    .background((viewModel.isLoading || viewModel.channelName.isEmpty) ? Color.blue.opacity(0.4) : Color.blue)
                    .cornerRadius(25)
                }
                .disabled(viewModel.isLoading || viewModel.channelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.top, 30)
            }
            
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("VoiceAgent")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
            }
            .navigationDestination(item: $viewModel.navigationData) { data in
                ChatView(uid: data.uid, token: data.token, channel: data.channel)
            }
            .alert("错误", isPresented: $viewModel.showError) {
                Button("确定", role: .cancel) { }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
}

#Preview {
    EntranceView()
}
