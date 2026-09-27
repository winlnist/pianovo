import SwiftUI
import WebKit

struct FullScoreSVGView: UIViewRepresentable {
    let svg: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.minimumZoomScale = 0.5
        webView.scrollView.maximumZoomScale = 3.0
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(htmlDocument(for: svg), baseURL: nil)
    }

    private func htmlDocument(for svg: String) -> String {
        """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
            html, body {
              margin: 0;
              padding: 0;
              background: #ffffff;
            }
            svg {
              display: block;
              width: 100%;
              height: auto;
            }
          </style>
        </head>
        <body>
          \(svg)
        </body>
        </html>
        """
    }
}
