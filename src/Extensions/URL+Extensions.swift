import Foundation

extension URL {
    func appendingToLastPathComponent(string: String) -> URL {
        let pathExtension = self.pathExtension
        var url = self.deletingPathExtension()
        
        let fileName = url.lastPathComponent + string
        url = url.deletingLastPathComponent()
        
        url = url.appendingPathComponent(fileName)
        url = url.appendingPathExtension(pathExtension)
        return url
    }
}
