import * as React from 'react';
import {NativeModules, findNodeHandle, UIManager } from 'react-native';
import { requireNativeComponent } from 'react-native';

const CLPCompositionPlayer = requireNativeComponent('CLPCompositionPlayer');

type Props = {
  onProgress: (e: any) => void;
  paused?: boolean
};

export const CompositionPlayer = React.forwardRef( ({onProgress, ...props}: Props, ref: any) => {
  const nativeComponentRef = React.useRef<typeof CLPCompositionPlayer>(null);
  React.useImperativeHandle(ref, () => ({
    seek: (time: number) => {
      nativeComponentRef.current.setNativeProps({ seek: { time } })
    },
    setPlaybackRate: (rate: number) => nativeComponentRef.current.setNativeProps({ rate }),
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
      onVideoProgress={(e: any) => onProgress && onProgress(e.nativeEvent)}
      ref={nativeComponentRef}
      {...props} 
    />
  );
})