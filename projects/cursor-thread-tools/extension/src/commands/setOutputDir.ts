import * as vscode from 'vscode';
import { join, isAbsolute } from 'path';
import { existsSync } from 'fs';

export async function setOutputDir(): Promise<void> {
  try {
    const workspaceFolders = vscode.workspace.workspaceFolders;
    if (!workspaceFolders || workspaceFolders.length === 0) {
      vscode.window.showWarningMessage('Thread Tools: Open a workspace first to set output directory.');
      return;
    }

    const config = vscode.workspace.getConfiguration('cursorThreadTools');
    const currentDir = config.get<string>('export.outputDir', '.thread-exports');

    const candidatePath = join(workspaceFolders[0].uri.fsPath, currentDir);
    const defaultUri = existsSync(candidatePath)
      ? vscode.Uri.file(candidatePath)
      : workspaceFolders[0].uri;

    const result = await vscode.window.showOpenDialog({
      canSelectFolders: true,
      canSelectFiles: false,
      canSelectMany: false,
      openLabel: 'Select Output Directory',
      defaultUri,
    });

    if (!result || result.length === 0) return;

    const selected = result[0];
    const relativePath = vscode.workspace.asRelativePath(selected, false);

    if (isAbsolute(relativePath)) {
      vscode.window.showWarningMessage(
        'Thread Tools: Selected folder is outside the workspace. Please select a folder within the workspace.',
      );
      return;
    }

    await config.update('export.outputDir', relativePath, vscode.ConfigurationTarget.Workspace);
    vscode.window.showInformationMessage(`Thread Tools: Output directory set to "${relativePath}"`);
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    vscode.window.showErrorMessage(`Thread Tools Set Output Dir: ${msg}`);
  }
}
