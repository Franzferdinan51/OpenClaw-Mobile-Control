import '../models/prompt_template.dart';

/// Default prompt templates included with the app
class DefaultPromptTemplates {
  /// All default templates
  static final List<PromptTemplate> all = [
    // ==================== CODING ====================
    PromptTemplate(
      id: 'code_review',
      title: 'Code Review',
      prompt: 'Please review the following code and provide feedback on:\n1. Code quality and best practices\n2. Potential bugs or issues\n3. Performance considerations\n4. Security concerns\n\n```\n{{code}}\n```',
      category: PromptCategory.coding,
      description: 'Comprehensive code review with best practices feedback',
      variables: const [
        PromptVariable(name: 'code', description: 'The code to review'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'explain_code',
      title: 'Explain Code',
      prompt: 'Please explain what this code does in simple terms:\n\n```\n{{code}}\n```\n\nBreak it down step by step and explain the purpose of each part.',
      category: PromptCategory.coding,
      description: 'Simple explanation of code functionality',
      variables: const [
        PromptVariable(name: 'code', description: 'The code to explain'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'refactor_code',
      title: 'Refactor Code',
      prompt: 'Please refactor this code to improve:\n- Readability\n- Performance\n- Maintainability\n- Follow best practices for {{language}}\n\n```\n{{code}}\n```\n\nProvide the refactored code with explanations of the changes.',
      category: PromptCategory.coding,
      description: 'Improve code quality and structure',
      variables: const [
        PromptVariable(name: 'code', description: 'The code to refactor'),
        PromptVariable(name: 'language', description: 'Programming language', defaultValue: 'the language'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'generate_function',
      title: 'Generate Function',
      prompt: 'Write a {{language}} function that {{description}}.\n\nRequirements:\n- Include proper error handling\n- Add documentation/comments\n- Follow {{language}} best practices\n- Include type hints if applicable',
      category: PromptCategory.coding,
      description: 'Generate a function based on description',
      variables: const [
        PromptVariable(name: 'language', description: 'Programming language'),
        PromptVariable(name: 'description', description: 'What the function should do'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'convert_code',
      title: 'Convert Code',
      prompt: 'Convert this {{from_language}} code to {{to_language}}:\n\n```\n{{code}}\n```\n\nMaintain the same functionality and provide idiomatic {{to_language}} code.',
      category: PromptCategory.coding,
      description: 'Convert code between languages',
      variables: const [
        PromptVariable(name: 'from_language', description: 'Source language'),
        PromptVariable(name: 'to_language', description: 'Target language'),
        PromptVariable(name: 'code', description: 'Code to convert'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'write_unit_tests',
      title: 'Write Unit Tests',
      prompt: 'Write comprehensive unit tests for this {{language}} code:\n\n```\n{{code}}\n```\n\nInclude:\n- Happy path tests\n- Edge cases\n- Error cases\n- Use appropriate testing framework for {{language}}',
      category: PromptCategory.testing,
      description: 'Generate unit tests for code',
      variables: const [
        PromptVariable(name: 'language', description: 'Programming language'),
        PromptVariable(name: 'code', description: 'Code to test'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    
    // ==================== DEBUGGING ====================
    PromptTemplate(
      id: 'debug_error',
      title: 'Debug Error',
      prompt: 'Help me debug this error:\n\nError message:\n```\n{{error}}\n```\n\nCode:\n```\n{{code}}\n```\n\nPlease:\n1. Explain what the error means\n2. Identify the root cause\n3. Provide a solution with code fix',
      category: PromptCategory.debugging,
      description: 'Debug and fix code errors',
      variables: const [
        PromptVariable(name: 'error', description: 'The error message'),
        PromptVariable(name: 'code', description: 'The problematic code'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'fix_bug',
      title: 'Fix Bug',
      prompt: 'I have a bug in my code where {{bug_description}}.\n\nExpected behavior: {{expected}}\nActual behavior: {{actual}}\n\nHere\'s the relevant code:\n```\n{{code}}\n```\n\nHelp me find and fix the bug.',
      category: PromptCategory.debugging,
      description: 'Identify and fix bugs in code',
      variables: const [
        PromptVariable(name: 'bug_description', description: 'Description of the bug'),
        PromptVariable(name: 'expected', description: 'Expected behavior'),
        PromptVariable(name: 'actual', description: 'Actual behavior'),
        PromptVariable(name: 'code', description: 'Relevant code'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'performance_issue',
      title: 'Performance Issue',
      prompt: 'Analyze this code for performance issues:\n\n```\n{{code}}\n```\n\nContext: {{context}}\n\nPlease identify:\n1. Performance bottlenecks\n2. Memory leaks or inefficiencies\n3. Algorithm complexity issues\n4. Provide optimized version with explanations',
      category: PromptCategory.debugging,
      description: 'Analyze and fix performance issues',
      variables: const [
        PromptVariable(name: 'code', description: 'Code to analyze'),
        PromptVariable(name: 'context', description: 'Context about how the code is used', required: false),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    
    // ==================== ARCHITECTURE ====================
    PromptTemplate(
      id: 'design_system',
      title: 'Design System Architecture',
      prompt: 'Design a system architecture for: {{description}}\n\nRequirements:\n{{requirements}}\n\nPlease provide:\n1. High-level architecture diagram (describe in text)\n2. Component breakdown\n3. Data flow\n4. Technology recommendations\n5. Scalability considerations',
      category: PromptCategory.architecture,
      description: 'Design system architecture',
      variables: const [
        PromptVariable(name: 'description', description: 'System description'),
        PromptVariable(name: 'requirements', description: 'System requirements'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'api_design',
      title: 'API Design',
      prompt: 'Design a REST API for: {{description}}\n\nRequirements:\n{{requirements}}\n\nProvide:\n1. Endpoints with HTTP methods\n2. Request/response schemas\n3. Authentication approach\n4. Error handling strategy\n5. Example requests/responses',
      category: PromptCategory.architecture,
      description: 'Design RESTful API',
      variables: const [
        PromptVariable(name: 'description', description: 'API purpose'),
        PromptVariable(name: 'requirements', description: 'Requirements and constraints'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'database_schema',
      title: 'Database Schema',
      prompt: 'Design a database schema for: {{description}}\n\nRequirements:\n{{requirements}}\n\nProvide:\n1. Entity-relationship diagram (describe in text)\n2. Table definitions with columns and types\n3. Indexes and constraints\n4. Sample queries',
      category: PromptCategory.architecture,
      description: 'Design database schema',
      variables: const [
        PromptVariable(name: 'description', description: 'What the database is for'),
        PromptVariable(name: 'requirements', description: 'Data and access requirements'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    
    // ==================== WRITING ====================
    PromptTemplate(
      id: 'write_email',
      title: 'Professional Email',
      prompt: 'Write a professional email about: {{subject}}\n\nTone: {{tone}}\nKey points to include:\n{{points}}\n\nWrite a clear, concise email that gets the message across professionally.',
      category: PromptCategory.writing,
      description: 'Write professional emails',
      variables: const [
        PromptVariable(name: 'subject', description: 'Email subject/main topic'),
        PromptVariable(name: 'tone', description: 'Tone (formal, friendly, etc.)', defaultValue: 'professional'),
        PromptVariable(name: 'points', description: 'Key points to include'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'write_blog',
      title: 'Blog Post',
      prompt: 'Write a blog post about: {{topic}}\n\nTarget audience: {{audience}}\nLength: {{length}}\nStyle: {{style}}\n\nInclude:\n- Engaging introduction\n- Clear structure with headers\n- Practical examples\n- Conclusion with key takeaways',
      category: PromptCategory.writing,
      description: 'Write engaging blog posts',
      variables: const [
        PromptVariable(name: 'topic', description: 'Blog topic'),
        PromptVariable(name: 'audience', description: 'Target audience', defaultValue: 'general readers'),
        PromptVariable(name: 'length', description: 'Word count', defaultValue: '800-1000 words'),
        PromptVariable(name: 'style', description: 'Writing style', defaultValue: 'informative and engaging'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'write_documentation',
      title: 'Technical Documentation',
      prompt: 'Write technical documentation for: {{subject}}\n\nTarget audience: {{audience}}\n\nInclude:\n1. Overview/Introduction\n2. Prerequisites\n3. Step-by-step instructions\n4. Code examples where relevant\n5. Troubleshooting section\n6. References/Resources',
      category: PromptCategory.documentation,
      description: 'Write technical documentation',
      variables: const [
        PromptVariable(name: 'subject', description: 'What to document'),
        PromptVariable(name: 'audience', description: 'Target audience (developers, users, etc.)'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'write_readme',
      title: 'README File',
      prompt: 'Create a README.md for a project named: {{project_name}}\n\nDescription: {{description}}\nTech stack: {{tech_stack}}\n\nInclude sections for:\n- Project title and description\n- Features\n- Installation\n- Usage\n- Configuration\n- Contributing\n- License',
      category: PromptCategory.documentation,
      description: 'Generate README files',
      variables: const [
        PromptVariable(name: 'project_name', description: 'Project name'),
        PromptVariable(name: 'description', description: 'Project description'),
        PromptVariable(name: 'tech_stack', description: 'Technologies used'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'improve_writing',
      title: 'Improve Writing',
      prompt: 'Please improve this text:\n\n"""\n{{text}}\n"""\n\nGoals:\n{{goals}}\n\nProvide the improved version with explanations of the changes made.',
      category: PromptCategory.writing,
      description: 'Improve clarity and quality of writing',
      variables: const [
        PromptVariable(name: 'text', description: 'Text to improve'),
        PromptVariable(name: 'goals', description: 'Improvement goals', defaultValue: 'Make clearer, more engaging, and error-free'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    
    // ==================== ANALYSIS ====================
    PromptTemplate(
      id: 'analyze_data',
      title: 'Analyze Data',
      prompt: 'Analyze this data and provide insights:\n\n{{data}}\n\nPlease provide:\n1. Summary statistics\n2. Key patterns and trends\n3. Notable outliers\n4. Recommendations based on findings\n5. Potential next steps for deeper analysis',
      category: PromptCategory.analysis,
      description: 'Analyze data and find insights',
      variables: const [
        PromptVariable(name: 'data', description: 'Data to analyze'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'compare_options',
      title: 'Compare Options',
      prompt: 'Compare these options and recommend the best one:\n\nOptions:\n{{options}}\n\nCriteria:\n{{criteria}}\n\nProvide:\n1. Detailed comparison table\n2. Pros and cons of each\n3. Scoring/ranking\n4. Final recommendation with reasoning',
      category: PromptCategory.analysis,
      description: 'Compare and recommend between options',
      variables: const [
        PromptVariable(name: 'options', description: 'Options to compare'),
        PromptVariable(name: 'criteria', description: 'Evaluation criteria'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'swot_analysis',
      title: 'SWOT Analysis',
      prompt: 'Conduct a SWOT analysis for: {{subject}}\n\nContext:\n{{context}}\n\nProvide a detailed SWOT analysis covering:\n- **Strengths**: Internal advantages\n- **Weaknesses**: Internal disadvantages\n- **Opportunities**: External possibilities\n- **Threats**: External risks\n\nInclude actionable recommendations.',
      category: PromptCategory.analysis,
      description: 'Conduct SWOT analysis',
      variables: const [
        PromptVariable(name: 'subject', description: 'What to analyze'),
        PromptVariable(name: 'context', description: 'Relevant context'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'root_cause',
      title: 'Root Cause Analysis',
      prompt: 'Perform a root cause analysis for: {{problem}}\n\nBackground:\n{{background}}\n\nUse the 5 Whys technique and provide:\n1. Problem statement\n2. Analysis chain (5 Whys)\n3. Root cause identification\n4. Contributing factors\n5. Recommended solutions\n6. Prevention measures',
      category: PromptCategory.analysis,
      description: 'Find root cause of problems',
      variables: const [
        PromptVariable(name: 'problem', description: 'The problem to analyze'),
        PromptVariable(name: 'background', description: 'Background context'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    
    // ==================== RESEARCH ====================
    PromptTemplate(
      id: 'research_topic',
      title: 'Research Topic',
      prompt: 'Research and summarize: {{topic}}\n\nFocus areas:\n{{focus_areas}}\n\nProvide:\n1. Overview and definition\n2. Key concepts and terminology\n3. Current state/latest developments\n4. Different perspectives\n5. Practical applications\n6. Further reading recommendations',
      category: PromptCategory.research,
      description: 'Deep research on a topic',
      variables: const [
        PromptVariable(name: 'topic', description: 'Topic to research'),
        PromptVariable(name: 'focus_areas', description: 'Specific areas to focus on', required: false),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'competitor_analysis',
      title: 'Competitor Analysis',
      prompt: 'Analyze competitors in the {{industry}} industry:\n\nCompetitors:\n{{competitors}}\n\nProvide:\n1. Company overviews\n2. Product/service comparison\n3. Market positioning\n4. Strengths and weaknesses\n5. Strategic recommendations',
      category: PromptCategory.research,
      description: 'Analyze market competitors',
      variables: const [
        PromptVariable(name: 'industry', description: 'Industry'),
        PromptVariable(name: 'competitors', description: 'List of competitors to analyze'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'tech_comparison',
      title: 'Technology Comparison',
      prompt: 'Compare these technologies: {{technologies}}\n\nUse case: {{use_case}}\n\nEvaluate based on:\n- Performance\n- Learning curve\n- Community and support\n- Cost\n- Scalability\n- Future outlook\n\nProvide a detailed comparison and recommendation.',
      category: PromptCategory.research,
      description: 'Compare technologies for a use case',
      variables: const [
        PromptVariable(name: 'technologies', description: 'Technologies to compare'),
        PromptVariable(name: 'use_case', description: 'Intended use case'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    
    // ==================== PRODUCTIVITY ====================
    PromptTemplate(
      id: 'summarize_text',
      title: 'Summarize Text',
      prompt: 'Summarize the following text:\n\n"""\n{{text}}\n"""\n\nSummary length: {{length}}\nFocus on: {{focus}}',
      category: PromptCategory.productivity,
      description: 'Create concise summaries',
      variables: const [
        PromptVariable(name: 'text', description: 'Text to summarize'),
        PromptVariable(name: 'length', description: 'Summary length', defaultValue: 'brief'),
        PromptVariable(name: 'focus', description: 'What to focus on', required: false),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'extract_key_points',
      title: 'Extract Key Points',
      prompt: 'Extract the key points from this text:\n\n"""\n{{text}}\n"""\n\nProvide:\n1. Main thesis/message\n2. Key supporting points\n3. Important data/statistics\n4. Action items (if any)\n5. Questions raised',
      category: PromptCategory.productivity,
      description: 'Extract key information from text',
      variables: const [
        PromptVariable(name: 'text', description: 'Text to analyze'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'create_outline',
      title: 'Create Outline',
      prompt: 'Create a detailed outline for: {{topic}}\n\nPurpose: {{purpose}}\nAudience: {{audience}}\n\nProvide a hierarchical outline with:\n- Main sections\n- Subsections\n- Key points for each section',
      category: PromptCategory.productivity,
      description: 'Create structured outlines',
      variables: const [
        PromptVariable(name: 'topic', description: 'What to outline'),
        PromptVariable(name: 'purpose', description: 'Purpose of the outline'),
        PromptVariable(name: 'audience', description: 'Target audience'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'generate_checklist',
      title: 'Generate Checklist',
      prompt: 'Create a checklist for: {{task}}\n\nContext: {{context}}\n\nProvide a comprehensive checklist organized by:\n1. Pre-task preparation\n2. Execution steps\n3. Quality checks\n4. Post-task wrap-up',
      category: PromptCategory.productivity,
      description: 'Generate actionable checklists',
      variables: const [
        PromptVariable(name: 'task', description: 'Task or process'),
        PromptVariable(name: 'context', description: 'Context and requirements'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'meeting_agenda',
      title: 'Meeting Agenda',
      prompt: 'Create a meeting agenda for: {{meeting_topic}}\n\nDuration: {{duration}}\nAttendees: {{attendees}}\nGoals: {{goals}}\n\nProvide:\n1. Meeting details\n2. Agenda items with time allocations\n3. Discussion points\n4. Expected outcomes\n5. Pre-meeting preparation needed',
      category: PromptCategory.productivity,
      description: 'Create effective meeting agendas',
      variables: const [
        PromptVariable(name: 'meeting_topic', description: 'Meeting topic/purpose'),
        PromptVariable(name: 'duration', description: 'Meeting duration', defaultValue: '1 hour'),
        PromptVariable(name: 'attendees', description: 'Expected attendees', required: false),
        PromptVariable(name: 'goals', description: 'Meeting goals'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'action_plan',
      title: 'Action Plan',
      prompt: 'Create an action plan for: {{goal}}\n\nTimeline: {{timeline}}\nResources: {{resources}}\nConstraints: {{constraints}}\n\nProvide:\n1. Goal breakdown\n2. Milestone timeline\n3. Action items with owners and deadlines\n4. Required resources\n5. Risk mitigation\n6. Success metrics',
      category: PromptCategory.productivity,
      description: 'Create detailed action plans',
      variables: const [
        PromptVariable(name: 'goal', description: 'Goal to achieve'),
        PromptVariable(name: 'timeline', description: 'Overall timeline'),
        PromptVariable(name: 'resources', description: 'Available resources', required: false),
        PromptVariable(name: 'constraints', description: 'Constraints to consider', required: false),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    
    // ==================== CREATIVE ====================
    PromptTemplate(
      id: 'brainstorm_ideas',
      title: 'Brainstorm Ideas',
      prompt: 'Brainstorm creative ideas for: {{topic}}\n\nContext: {{context}}\nQuantity goal: {{quantity}} ideas\nCategories: {{categories}}\n\nGenerate diverse, creative ideas and categorize them. For each idea, provide a brief description and potential implementation.',
      category: PromptCategory.creative,
      description: 'Generate creative ideas',
      variables: const [
        PromptVariable(name: 'topic', description: 'What to brainstorm about'),
        PromptVariable(name: 'context', description: 'Background context', required: false),
        PromptVariable(name: 'quantity', description: 'Number of ideas', defaultValue: '10'),
        PromptVariable(name: 'categories', description: 'Idea categories', required: false),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'creative_writing',
      title: 'Creative Writing',
      prompt: 'Write a creative piece about: {{topic}}\n\nGenre: {{genre}}\nTone: {{tone}}\nLength: {{length}}\n\nInclude vivid descriptions, engaging characters (if applicable), and a compelling narrative.',
      category: PromptCategory.creative,
      description: 'Creative writing assistance',
      variables: const [
        PromptVariable(name: 'topic', description: 'Writing topic/theme'),
        PromptVariable(name: 'genre', description: 'Genre (fiction, poetry, etc.)', defaultValue: 'fiction'),
        PromptVariable(name: 'tone', description: 'Tone (serious, humorous, etc.)', defaultValue: 'engaging'),
        PromptVariable(name: 'length', description: 'Length', defaultValue: 'short'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'product_name',
      title: 'Product Name Ideas',
      prompt: 'Generate product name ideas for: {{product_description}}\n\nTarget audience: {{audience}}\nBrand personality: {{personality}}\n\nGenerate 20+ unique name ideas and for each provide:\n- The name\n- Why it works\n- Potential issues\n\nCategorize by style (descriptive, abstract, playful, etc.)',
      category: PromptCategory.creative,
      description: 'Generate product name ideas',
      variables: const [
        PromptVariable(name: 'product_description', description: 'Product description'),
        PromptVariable(name: 'audience', description: 'Target audience'),
        PromptVariable(name: 'personality', description: 'Brand personality'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'social_media_post',
      title: 'Social Media Post',
      prompt: 'Create a {{platform}} post about: {{topic}}\n\nTone: {{tone}}\nGoal: {{goal}}\n\nInclude:\n- Engaging hook/opening\n- Key message\n- Call to action\n- Relevant hashtags',
      category: PromptCategory.creative,
      description: 'Create engaging social media posts',
      variables: const [
        PromptVariable(name: 'platform', description: 'Platform (Twitter, LinkedIn, etc.)'),
        PromptVariable(name: 'topic', description: 'Post topic'),
        PromptVariable(name: 'tone', description: 'Tone (professional, casual, etc.)'),
        PromptVariable(name: 'goal', description: 'Goal (engagement, awareness, etc.)'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    
    // ==================== COMMUNICATION ====================
    PromptTemplate(
      id: 'write_response',
      title: 'Write Response',
      prompt: 'Help me write a response to this message:\n\n"""\n{{original_message}}\n"""\n\nMy goal: {{goal}}\nTone: {{tone}}\n\nContext: {{context}}',
      category: PromptCategory.communication,
      description: 'Craft effective responses',
      variables: const [
        PromptVariable(name: 'original_message', description: 'Message to respond to'),
        PromptVariable(name: 'goal', description: 'Response goal'),
        PromptVariable(name: 'tone', description: 'Tone to use'),
        PromptVariable(name: 'context', description: 'Additional context', required: false),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'apologize',
      title: 'Write Apology',
      prompt: 'Help me write a sincere apology for: {{situation}}\n\nRelationship: {{relationship}}\nWhat happened: {{details}}\n\nThe apology should:\n- Acknowledge what went wrong\n- Take responsibility\n- Show genuine remorse\n- Offer to make it right\n- Avoid excuses',
      category: PromptCategory.communication,
      description: 'Write sincere apologies',
      variables: const [
        PromptVariable(name: 'situation', description: 'Situation requiring apology'),
        PromptVariable(name: 'relationship', description: 'Relationship to recipient'),
        PromptVariable(name: 'details', description: 'What happened'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'feedback',
      title: 'Give Feedback',
      prompt: 'Help me give constructive feedback about: {{topic}}\n\nRecipient: {{recipient}}\nContext: {{context}}\nKey points: {{points}}\n\nUse a constructive approach:\n- Start with positives\n- Be specific about issues\n- Provide actionable suggestions\n- End on an encouraging note',
      category: PromptCategory.communication,
      description: 'Give constructive feedback',
      variables: const [
        PromptVariable(name: 'topic', description: 'Feedback topic'),
        PromptVariable(name: 'recipient', description: 'Who receives feedback'),
        PromptVariable(name: 'context', description: 'Situation context'),
        PromptVariable(name: 'points', description: 'Key feedback points'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'difficult_conversation',
      title: 'Difficult Conversation',
      prompt: 'Help me prepare for a difficult conversation about: {{topic}}\n\nWith: {{person}}\nGoal: {{goal}}\n\nProvide:\n1. Key points to make\n2. Anticipated responses and how to handle them\n3. Questions to ask\n4. How to stay calm and constructive\n5. Possible outcomes and next steps',
      category: PromptCategory.communication,
      description: 'Prepare for difficult conversations',
      variables: const [
        PromptVariable(name: 'topic', description: 'Conversation topic'),
        PromptVariable(name: 'person', description: 'Who you\'re talking to'),
        PromptVariable(name: 'goal', description: 'Desired outcome'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    
    // ==================== LEARNING ====================
    PromptTemplate(
      id: 'explain_concept',
      title: 'Explain Concept',
      prompt: 'Explain {{concept}} in simple terms for {{audience}}.\n\nUse:\n- Simple language\n- Real-world analogies\n- Practical examples\n- Common misconceptions to avoid\n\nBreak it down step by step.',
      category: PromptCategory.learning,
      description: 'Explain concepts simply',
      variables: const [
        PromptVariable(name: 'concept', description: 'Concept to explain'),
        PromptVariable(name: 'audience', description: 'Target audience level', defaultValue: 'beginners'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'learn_topic',
      title: 'Learning Plan',
      prompt: 'Create a learning plan for: {{topic}}\n\nCurrent level: {{current_level}}\nTarget level: {{target_level}}\nTime available: {{time}}\n\nProvide:\n1. Learning objectives\n2. Recommended resources (books, courses, etc.)\n3. Step-by-step learning path\n4. Practice exercises\n5. Milestones to track progress\n6. Common pitfalls to avoid',
      category: PromptCategory.learning,
      description: 'Create structured learning plans',
      variables: const [
        PromptVariable(name: 'topic', description: 'What to learn'),
        PromptVariable(name: 'current_level', description: 'Current knowledge level'),
        PromptVariable(name: 'target_level', description: 'Desired level'),
        PromptVariable(name: 'time', description: 'Time available', defaultValue: 'a few hours per week'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'interview_prep',
      title: 'Interview Prep',
      prompt: 'Help me prepare for a {{job_title}} interview at {{company_type}}.\n\nExperience level: {{experience}}\n\nProvide:\n1. Common interview questions with suggested answers\n2. Technical questions/concepts to review\n3. Questions to ask the interviewer\n4. Tips for this type of interview\n5. Key topics to research',
      category: PromptCategory.learning,
      description: 'Prepare for job interviews',
      variables: const [
        PromptVariable(name: 'job_title', description: 'Position title'),
        PromptVariable(name: 'company_type', description: 'Type of company'),
        PromptVariable(name: 'experience', description: 'Your experience level'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'quiz_me',
      title: 'Quiz Me',
      prompt: 'Create a quiz to test my knowledge of: {{topic}}\n\nDifficulty: {{difficulty}}\nNumber of questions: {{count}}\n\nFormat:\n- Multiple choice\n- True/false\n- Short answer\n\nAfter each question, provide the correct answer and explanation.',
      category: PromptCategory.learning,
      description: 'Create knowledge quizzes',
      variables: const [
        PromptVariable(name: 'topic', description: 'Topic to quiz'),
        PromptVariable(name: 'difficulty', description: 'Difficulty level', defaultValue: 'medium'),
        PromptVariable(name: 'count', description: 'Number of questions', defaultValue: '10'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    
    // ==================== ADDITIONAL TEMPLATES ====================
    PromptTemplate(
      id: 'git_commit',
      title: 'Git Commit Message',
      prompt: 'Write a git commit message for these changes:\n\n{{changes}}\n\nFollow conventional commit format if applicable. Keep it concise but descriptive.',
      category: PromptCategory.coding,
      description: 'Generate git commit messages',
      variables: const [
        PromptVariable(name: 'changes', description: 'Description of changes made'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'regex_helper',
      title: 'Regex Helper',
      prompt: 'Create a regular expression to match: {{pattern_description}}\n\nLanguage: {{language}}\n\nProvide:\n1. The regex pattern\n2. Explanation of each part\n3. Examples of what it matches\n4. Examples of what it doesn\'t match',
      category: PromptCategory.coding,
      description: 'Create and explain regex patterns',
      variables: const [
        PromptVariable(name: 'pattern_description', description: 'What the regex should match'),
        PromptVariable(name: 'language', description: 'Programming language', defaultValue: 'any'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'sql_query',
      title: 'SQL Query Builder',
      prompt: 'Write a SQL query to: {{description}}\n\nTable(s): {{tables}}\nDatabase: {{database}}\n\nProvide the optimized query with comments explaining each part.',
      category: PromptCategory.coding,
      description: 'Build SQL queries',
      variables: const [
        PromptVariable(name: 'description', description: 'What the query should do'),
        PromptVariable(name: 'tables', description: 'Available tables'),
        PromptVariable(name: 'database', description: 'Database type', defaultValue: 'PostgreSQL'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'translate',
      title: 'Translate Text',
      prompt: 'Translate the following text from {{from_language}} to {{to_language}}:\n\n"""\n{{text}}\n"""\n\nProvide:\n1. Direct translation\n2. More natural/idiomatic translation if different\n3. Notes on any cultural nuances or idioms',
      category: PromptCategory.communication,
      description: 'Translate between languages',
      variables: const [
        PromptVariable(name: 'from_language', description: 'Source language'),
        PromptVariable(name: 'to_language', description: 'Target language'),
        PromptVariable(name: 'text', description: 'Text to translate'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'simplify_jargon',
      title: 'Simplify Jargon',
      prompt: 'Simplify this technical text for a non-technical audience:\n\n"""\n{{text}}\n"""\n\nReplace jargon with plain language while keeping the meaning accurate.',
      category: PromptCategory.writing,
      description: 'Make technical content accessible',
      variables: const [
        PromptVariable(name: 'text', description: 'Technical text to simplify'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'user_story',
      title: 'User Story',
      prompt: 'Write user stories for: {{feature}}\n\nUser type: {{user_type}}\nContext: {{context}}\n\nProvide:\n1. Main user story in standard format\n2. Acceptance criteria\n3. Edge cases to consider\n4. Related user stories',
      category: PromptCategory.productivity,
      description: 'Write user stories for features',
      variables: const [
        PromptVariable(name: 'feature', description: 'Feature description'),
        PromptVariable(name: 'user_type', description: 'Type of user'),
        PromptVariable(name: 'context', description: 'Product context', required: false),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'code_comment',
      title: 'Add Code Comments',
      prompt: 'Add helpful comments to this {{language}} code:\n\n```\n{{code}}\n```\n\nInclude:\n- Function/method documentation\n- Inline comments for complex logic\n- TODO notes for potential improvements',
      category: PromptCategory.documentation,
      description: 'Add documentation comments to code',
      variables: const [
        PromptVariable(name: 'language', description: 'Programming language'),
        PromptVariable(name: 'code', description: 'Code to comment'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'security_review',
      title: 'Security Review',
      prompt: 'Perform a security review of this code:\n\n```\n{{code}}\n```\n\nCheck for:\n1. SQL injection vulnerabilities\n2. XSS vulnerabilities\n3. Authentication/authorization issues\n4. Data validation problems\n5. Sensitive data exposure\n6. Rate limiting\n7. Other OWASP Top 10 issues',
      category: PromptCategory.testing,
      description: 'Security audit for code',
      variables: const [
        PromptVariable(name: 'code', description: 'Code to review'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'mock_data',
      title: 'Generate Mock Data',
      prompt: 'Generate mock data for: {{data_type}}\n\nFormat: {{format}}\nQuantity: {{quantity}} records\nFields needed: {{fields}}\n\nGenerate realistic test data.',
      category: PromptCategory.coding,
      description: 'Generate realistic mock/test data',
      variables: const [
        PromptVariable(name: 'data_type', description: 'Type of data (users, products, etc.)'),
        PromptVariable(name: 'format', description: 'Output format (JSON, CSV, etc.)', defaultValue: 'JSON'),
        PromptVariable(name: 'quantity', description: 'Number of records', defaultValue: '10'),
        PromptVariable(name: 'fields', description: 'Fields to include'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'error_message',
      title: 'User-Friendly Error',
      prompt: 'Convert this technical error into a user-friendly message:\n\nTechnical error: {{error}}\n\nContext: {{context}}\n\nProvide:\n1. User-friendly message\n2. Suggested action for the user\n3. Help documentation reference (if applicable)',
      category: PromptCategory.communication,
      description: 'Create user-friendly error messages',
      variables: const [
        PromptVariable(name: 'error', description: 'Technical error'),
        PromptVariable(name: 'context', description: 'Where this error occurs'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'optimize_prompt',
      title: 'Optimize Prompt',
      prompt: 'Optimize this prompt to get better results:\n\n"""\n{{original_prompt}}\n"""\n\nGoal: {{goal}}\n\nProvide:\n1. Analysis of the original prompt\'s weaknesses\n2. Optimized prompt\n3. Explanation of improvements made',
      category: PromptCategory.productivity,
      description: 'Improve prompts for AI',
      variables: const [
        PromptVariable(name: 'original_prompt', description: 'Original prompt'),
        PromptVariable(name: 'goal', description: 'What you want to achieve'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'json_schema',
      title: 'JSON Schema',
      prompt: 'Create a JSON Schema for data with this structure:\n\n{{description}}\n\nRequirements:\n{{requirements}}\n\nProvide:\n1. Complete JSON Schema\n2. Example valid JSON\n3. Validation notes',
      category: PromptCategory.coding,
      description: 'Create JSON Schema definitions',
      variables: const [
        PromptVariable(name: 'description', description: 'Data structure description'),
        PromptVariable(name: 'requirements', description: 'Validation requirements', required: false),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'cli_command',
      title: 'CLI Command Helper',
      prompt: 'Help me with a {{tool}} command to: {{goal}}\n\nOS: {{os}}\n\nProvide the command with:\n- Full command\n- Explanation of each flag/option\n- Common variations\n- Related commands',
      category: PromptCategory.coding,
      description: 'Build CLI commands',
      variables: const [
        PromptVariable(name: 'tool', description: 'CLI tool (git, docker, npm, etc.)'),
        PromptVariable(name: 'goal', description: 'What you want to do'),
        PromptVariable(name: 'os', description: 'Operating system', defaultValue: 'Linux/macOS'),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'docker_compose',
      title: 'Docker Compose',
      prompt: 'Create a Docker Compose file for: {{services}}\n\nRequirements:\n{{requirements}}\n\nInclude:\n- Service definitions\n- Networking\n- Volumes\n- Environment variables\n- Health checks\n- Restart policies',
      category: PromptCategory.architecture,
      description: 'Create Docker Compose configurations',
      variables: const [
        PromptVariable(name: 'services', description: 'Services to run'),
        PromptVariable(name: 'requirements', description: 'Specific requirements', required: false),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
    PromptTemplate(
      id: 'gitignore',
      title: 'Generate .gitignore',
      prompt: 'Create a .gitignore file for a {{project_type}} project.\n\nFrameworks/tools: {{tools}}\n\nInclude common patterns for:\n- IDE files\n- Build outputs\n- Dependencies\n- Environment files\n- OS-specific files',
      category: PromptCategory.coding,
      description: 'Generate .gitignore files',
      variables: const [
        PromptVariable(name: 'project_type', description: 'Type of project'),
        PromptVariable(name: 'tools', description: 'Frameworks and tools used', required: false),
      ],
      createdAt: DateTime(2024, 1, 1),
      isDefault: true,
    ),
  ];
  
  /// Get templates by category
  static List<PromptTemplate> getByCategory(PromptCategory category) {
    return all.where((t) => t.category == category).toList();
  }
  
  /// Get template by ID
  static PromptTemplate? getById(String id) {
    try {
      return all.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }
  
  /// Search templates
  static List<PromptTemplate> search(String query) {
    if (query.isEmpty) return all;
    
    final lowerQuery = query.toLowerCase();
    return all.where((t) {
      return t.title.toLowerCase().contains(lowerQuery) ||
          t.prompt.toLowerCase().contains(lowerQuery) ||
          (t.description?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }
}