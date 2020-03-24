import * as React from 'react';
import {NativeModules, findNodeHandle, UIManager } from 'react-native';
import { requireNativeComponent } from 'react-native';

const CLPCompositionPlayer = requireNativeComponent('CLPCompositionPlayer');

type Props = {
  onProgress: (e: { currentTime: number }) => void;
  onLoad: (e: { duration: number }) => void;
  onExportProgress: (e: { progress: number }) => void;
  paused?: boolean
};

export const CompositionPlayer = React.forwardRef( ({onProgress, onExportProgress, onLoad, ...props}: Props, ref: any) => {
  const nativeComponentRef = React.useRef<typeof CLPCompositionPlayer>(null);
  React.useImperativeHandle(ref, () => ({
    seek: (time: number) => {
      nativeComponentRef.current.setNativeProps({ seek: { time } })
    },
    setPlaybackRate: (rate: number) => null, // nativeComponentRef.current.setNativeProps({ rate }),
    play: () => null,
    pause: () => null,
    save: async (outputPath: string) => {
      return await NativeModules.CLPCompositionPlayerManager.save(
        outputPath,
        findNodeHandle(nativeComponentRef.current)
      );
    }
  }))
  
  return (
    <CLPCompositionPlayer
      onVideoLoad={(e: any) => onLoad && onLoad(e.nativeEvent)}
      onVideoProgress={(e: any) => onProgress && onProgress(e.nativeEvent)}
      onExportProgress={(e: any) => onExportProgress && onExportProgress(e.nativeEvent)}
      ref={nativeComponentRef}
      {...props} 
    />
  );
})