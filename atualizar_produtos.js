const fs = require('fs');
const path = require('path');

const produtosDir = path.join(__dirname, 'produtos');
const detalhesDir = path.join(produtosDir, 'detalhes');
const outputFile = path.join(__dirname, 'produtos_dados.js');

if (!fs.existsSync(detalhesDir)) {
  fs.mkdirSync(detalhesDir);
}

let produtosExistentes = {};

if (fs.existsSync(outputFile)) {
  const content = fs.readFileSync(outputFile, 'utf8');
  const match = content.match(/const listaProdutos = (\[[\s\S]*\]);/);
  if (match) {
    try {
      const json = JSON.parse(match[1]);
      json.forEach(p => {
        if (p.principal) {
          produtosExistentes[p.principal] = p;
        }
      });
    } catch (e) {
      console.error('Erro ao ler produtos existentes:', e);
    }
  }
}

try {
  const principalFiles = fs.readdirSync(produtosDir).filter(file => {
    return ['.jpg', '.jpeg', '.png', '.gif', '.jfif', '.webp'].includes(path.extname(file).toLowerCase());
  });

  const detalhesFiles = fs.readdirSync(detalhesDir).filter(file => {
    return ['.jpg', '.jpeg', '.png', '.gif', '.jfif', '.webp'].includes(path.extname(file).toLowerCase());
  });

  const newList = principalFiles.map(file => {
    if (produtosExistentes[file]) {
      const p = produtosExistentes[file];
      // Filtra detalhes que ainda existem na subpasta
      const validDetails = (p.detalhes || []).filter(d => detalhesFiles.includes(d));
      return {
        nome: p.nome || file.split('.')[0],
        preco: p.preco || 0.00,
        principal: file,
        detalhes: validDetails
      };
    } else {
      const defaultName = file.split('.')[0]
        .replace('Modelo', 'Produto ')
        .replace('modelo', 'Produto ')
        .trim();
      return {
        nome: defaultName,
        preco: 0.00,
        principal: file,
        detalhes: []
      };
    }
  });

  const finalContent = `const listaProdutos = ${JSON.stringify(newList, null, 2)};`;
  fs.writeFileSync(outputFile, finalContent);
  console.log('produtos_dados.js atualizado com sucesso (Detalhes em Subpasta)!');
} catch (err) {
  console.error('Erro ao atualizar produtos_dados.js:', err);
}