import * as React from 'react';
import {NativeModules, findNodeHandle } from 'react-native';
import { requireNativeComponent } from 'react-native';

const CLPCompositionPlayer = requireNativeComponent('CLPCompositionPlayer');

type Props = {
  onProgress: (e: { currentTime: number }) => void;
  onLoad: (e: { duration: number }) => void;
  onExportProgress: (e: { progress: number }) => void;
  paused?: boolean
};

export const CompositionPlayer = React.forwardRef( ({onProgress, onExportProgress, onLoad, ...props}: Props, ref: any) => {
  const compositionPlayerRe = React.useRef<typeof CLPCompositionPlayer>(null);
  
  React.useImperativeHandle(ref, () => ({
    seek: (time: number) => compositionPlayerRe.current.setNativeProps({ seek: { time } }),
    save: async (outputPath: string) => await NativeModules.CLPCompositionPlayerManager.save(outputPath, findNodeHandle(compositionPlayerRe.current))
  }));
  
  return (
    <CLPCompositionPlayer
      onVideoLoad={(e: any) => onLoad && onLoad(e.nativeEvent)}
      onVideoProgress={(e: any) => onProgress && onProgress(e.nativeEvent)}
      onExportProgress={(e: any) => onExportProgress && onExportProgress(e.nativeEvent)}
      ref={compositionPlayerRe}
      {...props} 
    />
  );
})