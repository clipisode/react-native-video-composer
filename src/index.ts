import { NativeModules } from "react-native";

const { VideoComposer } = NativeModules;

type Composition = {
  duration: number;
  videos: Array<{ path: string; startAt: number }>
};

export function compose(composition: Composition, output: string): Promise<string> {
  return VideoComposer.compose(composition, output);
}
