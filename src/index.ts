import { NativeModules } from "react-native";

type Options = {
  composition: {
    duration: number;
    videos: Array<{ path: string; startAt: number }>
  };
  exportId: string;
  output: string;
  onProgress?: (progress: number) => void
}

export function compose({composition, exportId, output}:Options): Promise<string> {
  const { VideoComposer } = NativeModules;

  return VideoComposer.compose(composition, exportId, output);
}

export function cancel(id: string) {
  const { VideoComposer } = NativeModules;

  return VideoComposer.cancelComposition(id);
}

export type CompositionEvent = 'progress' | 'error';

export function addListener(event: CompositionEvent, id: string, listener: ()=>void) {
  return null;
}