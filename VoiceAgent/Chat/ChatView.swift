//
//  ChatView.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/11/3.
//

import SwiftUI

struct ChatView: View {
    let uid: Int
    let token: String
    let channel: String
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ChatViewModel
    
    init(uid: Int, token: String, channel: String) {
        self.uid = uid
        self.token = token
        self.channel = channel
        _viewModel = StateObject(wrappedValue: ChatViewModel(uid: uid, token: token, channel: channel))
        UINavigationBar.setAnimationsEnabled(false)
    }
        
    var body: some View {
        VStack(spacing: 0) {
            // 字幕滚动视图
            TranscriptScrollView(transcripts: viewModel.transcripts)
            
            Spacer()
            
            // 通话控制栏
            ControlBarView(
                viewModel: viewModel,
                onEndCall: {
                    viewModel.endCall()
                    dismiss()
                }
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("VoiceAgent")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
        }
    }
}

// 通话控制栏组件
struct ControlBarView: View {
    @ObservedObject var viewModel: ChatViewModel
    let onEndCall: () -> Void
    
    var body: some View {
        HStack {
            Spacer()
            
            // 居中的按钮组
            HStack(spacing: 30) {
                // 麦克风控制组
                MicrophoneControlGroup(viewModel: viewModel)
                
                // 结束通话按钮
                EndCallButton(onEndCall: onEndCall)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
}

// 麦克风控制组
struct MicrophoneControlGroup: View {
    @ObservedObject var viewModel: ChatViewModel
    
    var body: some View {
        HStack(spacing: 8) {
            // 麦克风图标
            Button {
                viewModel.toggleMicrophone()
            } label: {
                Image(systemName: viewModel.isMicMuted ? "mic.slash.fill" : "mic.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.black)
            }
        }
    }
}

// 结束通话按钮
struct EndCallButton: View {
    let onEndCall: () -> Void
    
    var body: some View {
        Button {
            onEndCall()
        } label: {
            Image(systemName: "phone.down.fill")
                .font(.system(size: 24))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(Color.red)
                .clipShape(Circle())
        }
    }
}

// 字幕滚动视图
struct TranscriptScrollView: View {
    let transcripts: [Transcript]
    
    // 为每个字幕生成唯一标识符
    private func transcriptId(_ transcript: Transcript) -> String {
        return "\(transcript.turnId)_\(transcript.type.rawValue)_\(transcript.userId)"
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(transcripts.indices, id: \.self) { index in
                        let transcript = transcripts[index]
                        TranscriptRow(transcript: transcript)
                            .id(transcriptId(transcript))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .frame(maxHeight: .infinity)
            .onChange(of: transcripts.count) { _ in
                // 当有新字幕添加时，滚动到底部
                if let lastTranscript = transcripts.last {
                    let lastId = transcriptId(lastTranscript)
                    withAnimation {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }
}

// 字幕行视图
struct TranscriptRow: View {
    let transcript: Transcript
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 头像或标识
            Circle()
                .fill(transcript.type == .agent ? Color.blue : Color.green)
                .frame(width: 32, height: 32)
                .overlay(
                    Text(transcript.type == .agent ? "AI" : "我")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                )
            
            // 字幕内容
            Text(transcript.text)
                .font(.system(size: 15))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(white: 0.95))
        .cornerRadius(8)
    }
}

#Preview {
    ChatView(uid: 0, token: "", channel: "")
}
