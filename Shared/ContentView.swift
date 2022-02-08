//
//  ContentView.swift
//  Shared
//
//  Created by 张行 on 2022/1/25.
//

import SwiftUI
import SwiftShell

struct ContentView: View {
    @StateObject var viewModel = ContentViewModel()
    var body: some View {
        VStack {
            Form {
                TextField("WebHook:", text: $viewModel.webHookURL)
                Text(viewModel.text)
            }.padding()
        }
        .frame(width: 300, height: 100, alignment: .center)
        .onAppear {
            viewModel.startTimer()
        }
    }
        
}

@MainActor
class ContentViewModel: ObservableObject {
    @AppStorage("jenkins_ip") var ip:String = ""
    @Published var text = "";
    @Published var webHookURL = "" {
        didSet {
            if (webHookURL.isEmpty) {
                text = "请输入WebHook!"
            } else if URL(string: webHookURL) == nil {
                text = "WebHook不是一个正规的URL";
            } else {
                text = ""
            }
            cacheWebHookURL = webHookURL
        }
    }
    @AppStorage("cacheWebHookURL")
    var cacheWebHookURL = ""
    final private var timer:Timer?
    
    init() {
        webHookURL = cacheWebHookURL
    }
    
    func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true, block: { time in
//            self.text = "\(Date.now.timeIntervalSince1970)"
            /// ifconfig | grep "inet " | grep -v 127.0.0.1
            let output = SwiftShell.run("ifconfig")
            let contents = output.stdout.components(separatedBy: "\n\t")
            for content in contents {
                if (content.contains("inet ") && !content.contains("127.0.0.1")) {
                    let ip = content.components(separatedBy: " ")[1]
                    self.text = content
                    if (self.webHookIsOk() && ip != self.ip) {
                        self.ip = ip
                        self.sendWebHook(content: ip)
                    }
                    break;
                }
            }
        })
        timer?.fire()
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    func sendWebHook(content:String) {
        guard webHookIsOk() else {return}
        let messageString:[String:String] = ["content":"最新Jenkins打包地址:http://\(content):8080 账户:king 密码:1990823"]
        guard let url = URL(string: webHookURL) else {
            return
        }
        let messageJson: [String: Any] = ["text":messageString,"msgtype":"text"]
        let jsonData = try? JSONSerialization.data(withJSONObject: messageJson)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json;charset=utf-8", forHTTPHeaderField: "content-type")
        request.httpBody = jsonData
        let task = URLSession.shared.dataTask(with: request)
        task.resume()
    }
    
    func webHookIsOk() -> Bool {
        guard !webHookURL.isEmpty else {return false}
        guard let _ = URL(string: webHookURL) else {return false}
        return true
    }
    
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
