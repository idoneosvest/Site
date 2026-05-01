const fs = require('fs');
const path = require('path');
const readline = require('readline');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

const question = (query) => new Promise((resolve) => rl.question(query, resolve));

const produtosDir = path.join(__dirname, 'produtos');
const detalhesDir = path.join(produtosDir, 'detalhes');
const outputFile = path.join(__dirname, 'produtos_dados.js');

async function main() {
  let listaProdutos = [];

  if (fs.existsSync(outputFile)) {
    const content = fs.readFileSync(outputFile, 'utf8');
    // Captura tanto [] quanto {}
    const match = content.match(/const listaProdutos = (\{[\s\S]*\}|\[[\s\S]*?\]);/);
    if (match) {
      try {
        const parsed = JSON.parse(match[1]);
        // Garante que é um array
        listaProdutos = Array.isArray(parsed) ? parsed : [];
      } catch (e) {
        listaProdutos = [];
      }
    }
  }

  const getFiles = (dir) => fs.existsSync(dir) ? fs.readdirSync(dir).filter(f => ['.jpg', '.jpeg', '.png', '.jfif', '.webp'].includes(path.extname(f).toLowerCase())) : [];
  
  let principalFiles = getFiles(produtosDir);
  let detalhesFiles = getFiles(detalhesDir);

  // Sincronizar
  listaProdutos = listaProdutos.filter(p => principalFiles.includes(p.principal));
  listaProdutos.forEach(p => {
    p.detalhes = (p.detalhes || []).filter(d => detalhesFiles.includes(d));
    const base = path.parse(p.principal).name;
    detalhesFiles.filter(f => f.startsWith(base + '_detalhe')).forEach(d => {
      if (!p.detalhes.includes(d)) p.detalhes.push(d);
    });
  });

  // Novos
  principalFiles.forEach(f => {
    if (!listaProdutos.find(p => p.principal === f)) {
      const base = path.parse(f).name;
      listaProdutos.push({
        nome: base.replace('Modelo', 'Produto '),
        preco: 0.00,
        principal: f,
        detalhes: detalhesFiles.filter(d => d.startsWith(base + '_detalhe'))
      });
    }
  });

  while (true) {
    console.clear();
    console.log("=== GERENCIADOR DE PRODUTOS (NODE.JS) ===");
    listaProdutos.forEach((p, i) => {
      const num = `${i + 1}.`.padEnd(4);
      const nome = p.nome.padEnd(35);
      const preco = `R$ ${p.preco.toFixed(2).replace('.', ',')}`.padEnd(15);
      console.log(`${num} ${nome} | ${preco} | Fotos Detalhes: ${p.detalhes.length}`);
    });

    console.log("\nOpcoes: [Numero] Editar | [D] Deletar | [S] Salvar | [Q] Sair");
    const opt = (await question("Escolha: ")).toUpperCase();

    if (opt === 'S') {
      // Garante que sempre será um array, mesmo com 1 elemento
      const json = JSON.stringify(listaProdutos, null, 2);
      const content = `const listaProdutos = ${json};`;
      fs.writeFileSync(outputFile, content, 'utf8');
      console.log("Salvo!");
      break;
    }
    if (opt === 'Q') break;

    if (opt === 'D') {
        const dIdx = parseInt(await question("Numero do produto para EXCLUIR: ")) - 1;
        if (listaProdutos[dIdx]) {
            const p = listaProdutos[dIdx];
            const conf = (await question(`Tem certeza que deseja excluir '${p.nome}'? (S/N): `)).toUpperCase();
            if (conf === 'S') {
                // Deleta arquivos
                const pPath = path.join(produtosDir, p.principal);
                if (fs.existsSync(pPath)) fs.unlinkSync(pPath);
                p.detalhes.forEach(d => {
                    const dPath = path.join(detalhesDir, d);
                    if (fs.existsSync(dPath)) fs.unlinkSync(dPath);
                });
                // Remove da lista
                listaProdutos.splice(dIdx, 1);
                console.log("Produto removido!");
                await new Promise(r => setTimeout(resolve, 1000));
            }
        }
        continue;
    }

    const idx = parseInt(opt) - 1;
    if (listaProdutos[idx]) {
      const p = listaProdutos[idx];
      while (true) {
        console.clear();
        console.log(`--- EDITANDO: ${p.nome} ---`);
        console.log(`1. Nome: ${p.nome}`);
        console.log(`2. Preco: R$ ${p.preco}`);
        console.log(`3. Detalhes:`);
        p.detalhes.forEach((d, di) => console.log(`   [${di + 1}] ${d}`));

        console.log("\n[N] Nome | [P] Preco | [R] Remover Detalhe | [V] Voltar");
        const sub = (await question("Acao: ")).toUpperCase();

        if (sub === 'V') break;
        if (sub === 'N') p.nome = await question("Novo nome: ") || p.nome;
        if (sub === 'P') {
          const pr = await question("Novo preco: ");
          if (!isNaN(parseFloat(pr))) p.preco = parseFloat(pr);
        }
        if (sub === 'R' && p.detalhes.length > 0) {
          const rIdx = parseInt(await question("Numero do detalhe para remover: ")) - 1;
          if (p.detalhes[rIdx]) p.detalhes.splice(rIdx, 1);
        }
      }
    }
  }
  rl.close();
}

main();