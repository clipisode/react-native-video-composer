import { NativeModules, DeviceEventEmitter } from "react-native";

const { VideoComposer } = NativeModules;

type Options = {
  composition: {
    duration: number;
    videos: Array<{ path: string; startAt: number }>
  };
  exportId: string;
  output: string;
  onProgress?: (progress: number) => void
}

const eventPrefix = '@clipisode/react-native-video-composer';

VideoComposer.addListener(`${eventPrefix}:progress`);

export function compose({composition, exportId, output}:Options): Promise<string> {
  return VideoComposer.compose(composition, exportId, output);
}

export function cancel(id: string) {
  return VideoComposer.cancelComposition(id);
}

export type CompositionEvent = 'progress' | 'error';

export function addListener(event: CompositionEvent, id: string, listener: (data?:any)=>void) {
  return DeviceEventEmitter.addListener(`${eventPrefix}:${event}`, (data) => {
    // if (!uploadId || !data || !data.id || data.id === uploadId) {
    listener(data)
    // }
  });
}