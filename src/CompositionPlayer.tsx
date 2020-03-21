import * as React from 'react';
import { requireNativeComponent } from 'react-native';

const CLPCompositionPlayer = requireNativeComponent('CLPCompositionPlayer');

type Props = {
  paused?: boolean
};

export const CompositionPlayer = React.forwardRef( ({...props}: Props, ref: any) => {
  const nativeComponentRef = React.useRef<typeof CLPCompositionPlayer>(null);
  React.useImperativeHandle(ref, () => ({
    seek: (time: number) => {
      nativeComponentRef.current.setNativeProps({ seek: { time } })
    },
    setPlaybackRate: (rate: number) => nativeComponentRef.current.setNativeProps({ rate }),
    play: () => null,
    pause: () => null
  }))
  
  return <CLPCompositionPlayer ref={nativeComponentRef} {...props} />;
})