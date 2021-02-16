//
//  CropView.swift
//  CropViewController
//
//  Created by Никита Разумный on 11/5/17.
//  Copyright © 2017 resquare. All rights reserved.
//

import UIKit
import AVFoundation


struct Setting {
    static let std = Setting()
    
    let goodAreaColor = UIColor.green
    let badAreaColor  = UIColor.red
   
    let cornerSize : CGFloat = 25.0
    let cornerCount = 4
}

public class SECropView: UIView {
    
    // MARK: properties
    var areaQuadrangle = SEAreaView()
    // 四个点
    fileprivate var corners = [SECornerView]()
    fileprivate var cornerOnTouch: Int? = nil
    fileprivate var imageView : UIImageView?

	var isPathvalid: Bool {
		areaQuadrangle.isPathValid
	}

    public private(set) var cornerLocations : [CGPoint]?
    var first = true
    var path: CGMutablePath {
        let path = CGMutablePath()
        guard let firstPt = corners.first else {
            return path
        }
        let beginPt = CGPoint(x: firstPt.center.x - areaQuadrangle.frame.origin.x,
                             y: firstPt.center.y - areaQuadrangle.frame.origin.y)
        path.move(to: beginPt)
        for i in 1...3{
            let pt = CGPoint(x: corners[i % Setting.std.cornerCount].center.x - areaQuadrangle.frame.origin.x,
                             y: corners[i % Setting.std.cornerCount].center.y - areaQuadrangle.frame.origin.y)
            path.addLine(to: pt)
        }
        path.closeSubpath()
        return path
    }
    
    public var cornersLocationOnView : [CGPoint]? {
        guard let imageSize = imageView?.image?.size else { return nil }
        guard let imageViewFrame = imageView?.bounds else { return nil }
        guard let imageViewOrigin = imageView?.globalPoint else { return nil }
        guard let cropViewOrigin = self.globalPoint else { return nil }
        guard let cornersOnImage = cornerLocations else { return nil }
        
        let imageOrigin = AVMakeRect(aspectRatio: imageSize, insideRect: imageViewFrame).origin
        let shiftX = -cropViewOrigin.x + imageViewOrigin.x + imageOrigin.x + Setting.std.cornerSize / 2.0
        let shiftY = -cropViewOrigin.y + imageViewOrigin.y + imageOrigin.y + Setting.std.cornerSize / 2.0
        let shift = CGPoint(x: shiftX, y: shiftY)
        
        let pts = cornersOnImage.map {
            CGPoint(x: $0.x + shift.x, y: $0.y + shift.y)
        }
        
        print("pts: ", pts)
        return pts
    }
    
    // MARK: initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required public init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
        setup()
    }
    
    fileprivate func setup() {
        backgroundColor = UIColor.clear
        clipsToBounds = true
    }
    
    // MARK: layout
    
    fileprivate func pairPositionsAndViews() {
        if let cornerPositions = self.cornersLocationOnView {
            for i in 0 ..< Setting.std.cornerCount {
                self.corners[i].center = CGPoint(x: cornerPositions[i].x - Setting.std.cornerSize / 2.0,
                                            y: cornerPositions[i].y - Setting.std.cornerSize / 2.0)
            }
        }
        self.areaQuadrangle.fill(path: path)
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        if let imgsize = imageView?.image?.size, let imageBounds = imageView?.bounds {
            let f = AVMakeRect(aspectRatio: imgsize, insideRect: imageBounds)
            frame = f
            areaQuadrangle.frame = f
        }
        self.pairPositionsAndViews()
        self.update(scale: nil)
        
        guard first else {
            return
        }
        first = false
        let f = frame
        let first = f.origin
        let rhsTop = CGPoint(x: first.x + f.width, y: first.y)
        let lhsHip = CGPoint(x: first.x, y: first.y + f.height)
        let end = CGPoint(x: rhsTop.x, y: lhsHip.y)
        let dots = [first, rhsTop, end, lhsHip]
        self.cornerLocations = dots
        corners.enumerated().forEach { (info) in
            info.element.frame.origin = dots[info.offset]
        }
        areaQuadrangle.frame = bounds
        areaQuadrangle.isPathValid = SEQuadrangleHelper.checkConvex(corners: dots)
        for corner in self.corners {
            corner.layer.borderColor = (areaQuadrangle.isPathValid ? Setting.std.goodAreaColor : Setting.std.badAreaColor ).cgColor
            corner.scaleDown()
        }
        pairPositionsAndViews()
    }
    
    public func configureWithCorners(on imageView: UIImageView) {
        
        self.imageView = imageView
        self.imageView?.isUserInteractionEnabled = true
        imageView.addSubview(self)
        
        for subview in subviews {
            if subview is SECornerView {
                subview.removeFromSuperview()
            }
        }
        
        for _ in 0..<Setting.std.cornerCount {
            let corner = SECornerView(frame: CGRect(x: 0, y: 0, width: Setting.std.cornerSize, height: Setting.std.cornerSize))
            addSubview(corner)
            corners.append(corner)
        }
        areaQuadrangle.backgroundColor = .clear
        addSubview(areaQuadrangle)
    }
    
    public func setCorners(newCorners: [CGPoint]) {
		areaQuadrangle.isPathValid = SEQuadrangleHelper.checkConvex(corners: newCorners)
        for i in 0 ..< Setting.std.cornerCount {
            cornerLocations?[i] = newCorners[i]
			corners[i].layer.borderColor = (areaQuadrangle.isPathValid ? Setting.std.goodAreaColor : Setting.std.badAreaColor ).cgColor
        }
        pairPositionsAndViews()
    }
    
    fileprivate func update(scale isBigger: Bool?) {
        guard let touchIdx = cornerOnTouch else {
            return
        }
        if let bigger = isBigger{
            switch bigger {
            case true:
                corners[touchIdx].scaleUp()
            case false:
                corners[touchIdx].scaleDown()
            }
        }
        
        self.areaQuadrangle.isPathValid = SEQuadrangleHelper.checkConvex(corners: corners.map{ $0.center })
        for corner in corners {
            corner.layer.borderColor = (self.areaQuadrangle.isPathValid ? Setting.std.goodAreaColor : Setting.std.badAreaColor).cgColor
        }
    }

    // MARK: touches handling
    
    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        guard touches.count == 1, let first = touches.first else {
            return
        }
        let point = first.location(in: self)
        var bestDistance: CGFloat = 1000.0 * 1000.0 * 1000.0
        
        for i in 0 ..< Setting.std.cornerCount {
            let tmpPoint = corners[i].center
            let distance : CGFloat =
                (point.x - tmpPoint.x) * (point.x - tmpPoint.x) +
                (point.y - tmpPoint.y) * (point.y - tmpPoint.y)
            if distance < bestDistance {
                bestDistance = distance
                cornerOnTouch = i
            }
        }
        update(scale: true)
    }
    
    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard let touchIdx = cornerOnTouch, touches.count == 1, let first = touches.first else {
            return
        }
        let from = first.previousLocation(in: self)
        let to = first.location(in: self)
        let derivative = CGPoint(x: to.x - from.x, y: to.y - from.y)
        update(scale: nil)

        guard let cornerLocations = cornerLocations, let img = imageView?.image else { return }
        let rawPt = CGPoint(x: cornerLocations[touchIdx].x + derivative.x, y: cornerLocations[touchIdx].y + derivative.y)
        let newCenterOnImage = rawPt.normalized(size: img.size)
        self.cornerLocations?[touchIdx] = newCenterOnImage
        print(newCenterOnImage)
        
        pairPositionsAndViews()
    }
    
    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        guard cornerOnTouch != nil, touches.count == 1 else {
            return
        }
        update(scale: false)
        cornerOnTouch = nil
    }
}
