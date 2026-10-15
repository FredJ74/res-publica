// Adaptateur des bancs JavaScriptCore pour Node, pas un serveur de jeu.
// Le lanceur garde ses sources, ses assertions et son controle de verdict.
const moteurProcess = process;
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const racine = path.resolve(__dirname, '../..');
globalThis.print = (...args) => moteurProcess.stdout.write(args.join(' ') + '\n');
globalThis.readFile = fichier => fs.readFileSync(
  fichier.replace(/^\/Users\/fredericjasseron\/ResPublica(?=\/)/, racine), 'utf8');
globalThis.load = fichier => vm.runInThisContext(readFile(fichier), {filename:fichier});
// Les anciens bancs drainent explicitement les promesses, comme sous jsc.
globalThis.drainMicrotasks = () => moteurProcess._tickCallback();
globalThis.quit = code => moteurProcess.exit(code || 0);
globalThis.checkSyntax = fichier => { new vm.Script(readFile(fichier), {filename:fichier}); return true; };
const args = moteurProcess.argv.slice(2);
if (args[0] === '-e') vm.runInThisContext(args[1]);
else for (const fichier of args) load(fichier);
