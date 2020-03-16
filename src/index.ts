import { NativeModules } from "react-native";

type Composition = {
  duration: number;
  videos: Array<{ path: string; startAt: number }>
};

export function compose(composition: Composition, output: string): Promise<string> {
  const { VideoComposer } = NativeModules;

  return VideoComposer.compose(composition, output);
}
