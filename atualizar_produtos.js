const fs = require('fs');
const path = require('path');

const produtosDir = path.join(__dirname, 'produtos');
const outputFile = path.join(__dirname, 'produtos_dados.js');

let produtosExistentes = {};

if (fs.existsSync(outputFile)) {
  const content = fs.readFileSync(outputFile, 'utf8');
  const match = content.match(/const listaProdutos = (\[[\s\S]*\]);/);
  if (match) {
    try {
      const json = JSON.parse(match[1]);
      json.forEach(p => {
        // Suporta tanto o formato antigo (string) quanto o novo (array)
        const key = Array.isArray(p.imagens) ? p.imagens[0] : (p.imagem || '');
        if (key) {
          produtosExistentes[key] = p;
        }
      });
    } catch (e) {
      console.error('Erro ao ler produtos existentes:', e);
    }
  }
}

try {
  const files = fs.readdirSync(produtosDir).filter(file => {
    return ['.jpg', '.jpeg', '.png', '.gif', '.jfif', '.webp'].includes(path.extname(file).toLowerCase());
  });

  const newList = files.map(file => {
    if (produtosExistentes[file]) {
      const p = produtosExistentes[file];
      // Garante que o formato final seja com 'imagens' (array)
      return {
        imagens: Array.isArray(p.imagens) ? p.imagens : [p.imagem || file],
        preco: p.preco || 0.00,
        nome: p.nome || file.split('.')[0]
      };
    } else {
      const defaultName = file.split('.')[0]
        .replace('Modelo', 'Produto ')
        .replace('modelo', 'Produto ')
        .trim();
      return {
        imagens: [file],
        preco: 0.00,
        nome: defaultName
      };
    }
  });

  const finalContent = `const listaProdutos = ${JSON.stringify(newList, null, 2)};`;
  fs.writeFileSync(outputFile, finalContent);
  console.log('produtos_dados.js atualizado com sucesso (Modo Carrossel)!');
} catch (err) {
  console.error('Erro ao atualizar produtos_dados.js:', err);
}