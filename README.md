# Spline

This is the demo app that accompanied my [AVFoundation talk][ss] at the [Toronto Area Cocoa & Web Objects Developers Group][tacow] on May 14, 2013. It showcases capture, composition, a custom player and scrubber interface, synchronized CAAnimations, and real-time VFX. I hope you find it useful. Spline is a funny word.

[tacow]:http://tacow.org "tacow.org"
[ss]:http://www.slideshare.net/rydermackay/avfoundation-tacow-2013-05-14 "SlideShare.net: AVFoundation @ TACOW 2013 05 14"

## Requirements
Universal app. iOS 6 only.

## RGMRecordingViewController

This is a very simple implementation of the popular video app [Vine][v]. Tap the camera button to start a capture session. The gimmick: it only writes samples while your finger is on the screen. Tap the stop button to render the composition to disk.

[v]: http://vine.co "Vine.co"

## RGMPlayerViewController

Tap a video to view it in a custom player. This demonstrates use of `<AVAsynchronousKeyValueLoading>` to load track info, thumbnail generation, transport controls, periodic observation and looping. Hit the "Add Magic" button and drag your finger around the screen to record a CAKeyframeAnimation in synchrony with the current player item. Scrub the timeline to seek through the animation.

## RGMGLPlayerViewController

Tap the disclosure buttons (…) to open a GLKView-based player. This uses the new `AVPlayerItemVideoDataOutput` class to collect and process sample buffers from a video file during playback on the GPU. Use the slider to change the intensity of a `CIColorMonochrome` filter *in real-time!*

## Additional Resources

- WWDC 2012 Session 517: Real-time media effects and processing during playback
- [AVBasicVideoOutput][avbvo]
- [AVSimpleEditoriOS][avse]
- [AVLoupe][avl]
- [RosyWriter][rw]
- Brad Larson -- [GPUImage][gpu]
- Bob McCune -- [AVFoundationEditor][avf]
- Bill Dudney -- [AVCoreImageIntegration][avc]

[avbvo]:http://developer.apple.com/library/ios/#samplecode/AVBasicVideoOutput/Introduction/Intro.html "developer.apple.com: AVBasicVideoOutput"
[avse]:http://developer.apple.com/library/ios/#samplecode/AVSimpleEditoriOS/Introduction/Intro.html "AVSimpleEditoriOS"
[avl]:https://developer.apple.com/library/ios/#samplecode/AVLoupe/Introduction/Intro.html "AVLoupe"
[rw]:http://developer.apple.com/library/ios/#samplecode/RosyWriter/Introduction/Intro.html "RosyWriter"
[gpu]:https://github.com/bradlarson/GPUImage "github.com: BradLarson/GPUImage"
[avf]:https://github.com/tapharmonic/AVFoundationEditor "github.com: tapharmonic/AVFoundationEditor"
[avc]:https://github.com/bdudney/Experiments "github.com: bdudney/Experiments"

## Contact
Ryder Mackay	
Twitter: [@rydermackay][tw]		
ADN: [@ryder][adn]	
[http://analogkid.ca][ak]	

[tw]: https://twitter.com/rydermackay "Twitter: @rydermackay"
[adn]: https://alpha.app.net/ryder "App.net: @ryder"
[ak]: http://analogkid.ca "The Analog Kid"