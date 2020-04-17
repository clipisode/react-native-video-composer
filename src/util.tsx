import {NativeModules} from 'react-native';

export async function getDuration(assetPath: string): Promise<number> {
  return await NativeModules.CLPVideoUtil.getDuration(assetPath);
}