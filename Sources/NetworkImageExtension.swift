//
//  NetworkImageExtension.swift
//  NetworkImageExtension
//
//  Created by LawLincoln on 16/10/17.
//  Copyright © 2016年 SelfStudio. All rights reserved.
//

// MARK: - NetworkImageExtension
import UIKit

public protocol NetworkImageExtensionProtocol: class {
    var ne_imageFillTarget: (CALayer?, UIImageView?) { get }
}

extension UIImageView: NetworkImageExtensionProtocol {
    public var ne_imageFillTarget: (CALayer?, UIImageView?) { return (nil, self) }
}

extension CALayer: NetworkImageExtensionProtocol {
    public var ne_imageFillTarget: (CALayer?, UIImageView?) { return (self, nil) }
}

private struct NetworkImageExtensionAssociatedKeys {
    static var Task = "Task"
    static var URL = "URL"
}

private struct NetworkImageExtensionCacheManager {
    fileprivate static var session: URLSession?
    
    fileprivate static func ne_store(image: UIImage?, for url: URL?) {
        guard let value = url, let img = image else { return }
        DispatchQueue.global().async {
            let request = URLRequest(url: value, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 60 * 60 * 24 * 7)
            guard let d = UIImageJPEGRepresentation(img, 1) else { return }
            let ur = URLResponse(url: value, mimeType: "image/jpeg", expectedContentLength: d.count, textEncodingName: nil)
            let cr = CachedURLResponse(response: ur, data: d)
            URLCache.shared.storeCachedResponse(cr, for: request)
        }
    }
    
    fileprivate static func ne_cachedImage(for url: URL?) -> UIImage? {
        guard let value = url else { return nil }
        let request = URLRequest(url: value, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 60 * 60 * 24 * 7)
        if let d = URLCache.shared.cachedResponse(for: request)?.data, let image = UIImage(data: d) {
            return image
        }
        return nil
    }
}


public extension NetworkImageExtensionProtocol {
    
    private var some: AnyObject {
        return ne_imageFillTarget.0 ?? ne_imageFillTarget.1!
    }
    
    private var _downloadTask: URLSessionTask? {
        get { return objc_getAssociatedObject(some, &NetworkImageExtensionAssociatedKeys.Task) as? URLSessionTask
        }
        set(val) { objc_setAssociatedObject(some, &NetworkImageExtensionAssociatedKeys.Task, val, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    private var _oldURL: URL? {
        get { return objc_getAssociatedObject(some, &NetworkImageExtensionAssociatedKeys.URL) as? URL
        }
        set(val) { objc_setAssociatedObject(some, &NetworkImageExtensionAssociatedKeys.URL, val, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    public var urlSession: URLSession? {
        if NetworkImageExtensionCacheManager.session == nil {
            NetworkImageExtensionCacheManager.session = URLSession(configuration:  URLSessionConfiguration.default)
        }
        return NetworkImageExtensionCacheManager.session
    }
    
    public func ne_imageFor(url: URL?) {
        if let img = NetworkImageExtensionCacheManager.ne_cachedImage(for: url)  {
            if let layer = ne_imageFillTarget.0 {
                layer.contents = img.cgImage
            } else if let imgv = ne_imageFillTarget.1 {
                imgv.image = img
            }
        }
    }
    
    public func ne_setImageBy(_ URLString: String) {
        guard let value = URL(string: URLString) else { return }
        ne_imageWith(value)
    }
    
    public func ne_imageWith(_ url: URL!, complete: @escaping(UIImage) -> Void = { _ in }) {
        _downloadTask?.cancel()
        guard let value = url else { return }
        if _oldURL == value  { return }
        if let image = NetworkImageExtensionCacheManager.ne_cachedImage(for: value) {
            _oldURL = value
            DispatchQueue.main.async(execute: {
                if let layer = self.ne_imageFillTarget.0 {
                    layer.ne_fadeSetContent(image)
                } else if let imgv = self.ne_imageFillTarget.1 {
                    imgv.image = image
                }
                complete(image)
            })
            return
        }
        let request = URLRequest(url: value, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 20)
        
        DispatchQueue.global(qos: .userInteractive).async(execute: {
            let task = self.urlSession?.dataTask(with: request, completionHandler: { [weak self](data, resp, _) in
                if let d = data, let img = UIImage(data: d), let sself = self {
                    if let reps = resp {
                        let cache = CachedURLResponse(response: reps, data: d)
                        URLCache.shared.storeCachedResponse(cache, for: request)
                    }
                    sself._oldURL = value
                    NetworkImageExtensionCacheManager.ne_store(image: img, for: value)
                    
                    DispatchQueue.main.async(execute: {
                        if let layer = sself.ne_imageFillTarget.0 {
                            layer.ne_fadeSetContent(img)
                        } else if let imgv = sself.ne_imageFillTarget.1 {
                            imgv.image = img
                        }
                        complete(img)
                    })
                }
            })
            task?.resume()
            self._downloadTask = task
        })
    }
    
}

extension CALayer {
    
    fileprivate func ne_fadeSetContent(_ image: UIImage!, duration: TimeInterval = 0.2) {
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1
        fade.duration = duration
        fade.isRemovedOnCompletion = false
        add(fade, forKey: "opacity")
        contents = image.cgImage
    }
}
