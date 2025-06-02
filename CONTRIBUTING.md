# Contributing to ChaosChain DVN PoC

Thank you for your interest in contributing to the ChaosChain's Decentralized Verification Network! We welcome contributions from the community and are excited to see what you'll build.

## 🚀 Getting Started

### Prerequisites
- Node.js v16+
- npm or yarn
- Git
- Basic understanding of Solidity and Ethereum

### Development Setup

1. **Fork the repository**
   ```bash
   # Fork on GitHub, then clone your fork
   git clone https://github.com/YOUR_USERNAME/chaoschain-dvn.git
   cd chaoschain-dvn
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Set up environment**
   ```bash
   cp config/environment.example .env
   # Edit .env with your local configuration
   ```

4. **Compile and test**
   ```bash
   npm run compile
   npm test
   ```

## 📋 How to Contribute

### Types of Contributions

We welcome several types of contributions:

- 🐛 **Bug fixes** - Fix issues in smart contracts or scripts
- ✨ **New features** - Add functionality to existing contracts
- 📚 **Documentation** - Improve docs, comments, or examples
- 🧪 **Testing** - Add test cases or improve test coverage
- 🎨 **UI/UX** - Frontend improvements (Phase 2+)
- 🤖 **Agent Scripts** - Python agent implementations (Phase 2)

### Contribution Process

1. **Check existing issues** - Look at [GitHub Issues](https://github.com/chaoschain/chaoschain-dvn/issues) to see what needs work

2. **Create an issue** (if one doesn't exist)
   - Describe the problem or feature
   - Include relevant details and context
   - Wait for maintainer feedback before starting work

3. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/bug-description
   ```

4. **Make your changes**
   - Follow our coding standards (see below)
   - Add tests for new functionality
   - Update documentation as needed

5. **Test your changes**
   ```bash
   npm test
   npm run compile
   ```

6. **Commit your changes**
   ```bash
   git add .
   git commit -m "feat: add new consensus algorithm"
   # or
   git commit -m "fix: resolve staking calculation bug"
   ```

7. **Push and create PR**
   ```bash
   git push origin feature/your-feature-name
   ```
   Then create a Pull Request on GitHub.

## 🔧 Development Guidelines

### Coding Standards

#### Solidity Contracts
- Use Solidity 0.8.19+
- Follow [Solidity Style Guide](https://docs.soliditylang.org/en/latest/style-guide.html)
- Include comprehensive NatSpec documentation
- Use OpenZeppelin libraries for security
- Optimize for gas efficiency

Example:
```solidity
/**
 * @title MyContract
 * @notice Brief description of what this contract does
 * @dev Technical details for developers
 */
contract MyContract {
    /// @notice Brief description of state variable
    uint256 public myVariable;
    
    /**
     * @notice Brief description of function
     * @param param1 Description of parameter
     * @return result Description of return value
     */
    function myFunction(uint256 param1) external pure returns (uint256 result) {
        // Implementation
    }
}
```

#### JavaScript/TypeScript
- Use ES6+ syntax
- Follow consistent indentation (2 spaces)
- Add JSDoc comments for functions
- Use meaningful variable names

#### Python (Phase 2)
- Follow PEP 8 style guide
- Use type hints where appropriate
- Include docstrings for functions and classes
- Use meaningful variable names

### Testing Requirements

All contributions must include appropriate tests:

#### Smart Contract Tests
```javascript
describe("ContractName", function () {
    let contract;
    let owner, addr1, addr2;
    
    beforeEach(async function () {
        // Setup code
    });
    
    describe("Function Group", function () {
        it("Should do something specific", async function () {
            // Test implementation
            expect(result).to.equal(expected);
        });
    });
});
```

#### Test Coverage
- Aim for >80% test coverage
- Test both happy paths and edge cases
- Include failure scenarios
- Test access controls and modifiers

### Commit Message Format

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
type(scope): description

[optional body]

[optional footer]
```

Types:
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation changes
- `test:` - Adding tests
- `refactor:` - Code refactoring
- `style:` - Code style changes
- `chore:` - Maintenance tasks

Examples:
```
feat(consensus): add reputation-weighted voting
fix(registry): resolve duplicate agent registration
docs(readme): update installation instructions
test(studio): add submission workflow tests
```

## 🧪 Testing

### Running Tests

```bash
# Run all tests
npm test

# Run specific test file
npx hardhat test tests/unit/DVNRegistry.test.js

# Run with gas reporting
REPORT_GAS=true npm test

# Generate coverage report
npm run coverage
```

### Writing Tests

- Place unit tests in `tests/unit/`
- Place integration tests in `tests/integration/`
- Use descriptive test names
- Group related tests in `describe` blocks
- Use `beforeEach` for setup
- Assert expected outcomes clearly

## 📚 Documentation

### Documentation Standards

- Use clear, concise language
- Include code examples
- Update relevant docs when making changes
- Use proper markdown formatting

### Documentation Types

- **Code Comments**: Inline documentation in source files
- **API Documentation**: Function and contract interfaces
- **User Guides**: How-to guides for end users
- **Developer Guides**: Technical implementation details

## 🔒 Security

### Security Considerations

- Never commit private keys or secrets
- Follow smart contract security best practices
- Use OpenZeppelin security patterns
- Consider reentrancy attacks
- Validate all inputs
- Use proper access controls

### Reporting Security Issues

**Do NOT create public issues for security vulnerabilities.**

Instead, email: security@chaoschain.io

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

## 📖 Resources

### Learning Resources
- [Solidity Documentation](https://docs.soliditylang.org/)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)
- [Hardhat Documentation](https://hardhat.org/docs)
- [Ethereum Development](https://ethereum.org/en/developers/)

### Project-Specific Docs
- [Setup Guide](docs/SETUP.md)
- [Architecture Overview](docs/ARCHITECTURE.md)
- [Phase 1 Summary](PHASE_1_COMPLETION_SUMMARY.md)

## 🤝 Community

### Getting Help

- **GitHub Discussions**: [Project discussions](https://github.com/chaoschain/chaoschain-dvn/discussions)
- **Issues**: [Report bugs or request features](https://github.com/chaoschain/chaoschain-dvn/issues)
- **Discord**: [Join our Discord](https://discord.gg/chaoschain) (coming soon)

### Code of Conduct

Be respectful and inclusive. We follow the [Contributor Covenant](https://www.contributor-covenant.org/).

## 📋 Issue Templates

When creating issues, please use these templates:

### Bug Report
```markdown
**Bug Description**
Clear description of the bug

**Steps to Reproduce**
1. Step one
2. Step two
3. Bug occurs

**Expected Behavior**
What should happen

**Actual Behavior**
What actually happens

**Environment**
- Node.js version:
- Hardhat version:
- OS:
```

### Feature Request
```markdown
**Feature Description**
Clear description of the proposed feature

**Use Case**
Why is this feature needed?

**Proposed Solution**
How should this feature work?

**Alternatives Considered**
Other approaches you've considered
```

## 🏆 Recognition

Contributors will be:
- Listed in our Contributors section
- Recognized in release notes
- Invited to join our Discord contributor channel
- Considered for future bounty programs

Thank you for contributing to the future of decentralized AI agent collaboration! 🚀 