---
title: Principles
layout: docs
permalink: /docs/principles.html
---

The following principles guide the design and development of the AsyncDisplayKit framework.  

## 1. Reliable

- **What:** Behavior should match the documentation. The framework shouldn't crash in production, even when used incorrectly.
- **Why:** If the framework is not reliable, then it cannot be used in production apps. More importantly, it will drain the morale of the engineers working on it.
- **How:** Meaningful, stable unit tests. We will devote a significant chunk of our resources to build unit tests.

## 2. Familiar

- **What:** Interfaces should match industry standards such as UIKit and CSS when possible. When we diverge from these standards, the interfaces should as be intuitive and direct as possible.
- **Why:** If the framework is not familiar, then companies will be wary about adopting it. Engineers trained in UIKit, especially junior ones, will be frustrated and unproductive.
- **How:** Compare API to other mature frameworks, reach out to users when developing new API to get feedback. Be generous with abstraction layers – as long as we don't sacrifice Reliable.

## 3. Lean

- **What:** Speed and memory conservation should be industry-leading, the API should be concise, and implementation code should be short and organized.
- **Why:** Performance is at the heart of AsyncDisplayKit. It's what we do and we do it better than anyone else. In addition, a concise codebase and API are easier to maintain and learn. Plus it's just the right thing to do.
- **How:** Look for opportunities to improve performance. Think about the performance implications of each line of code. Dedicate resources to refactoring. Build tools to gather and expose performance metrics.

## 4. Bold

- **What:** Ambitious features, such as animated layout transitioning or our visibility-depth system, should be added from time to time.
- **Why:** Cutting-edge, never-before-seen tech gets people excited about the framework, and can raise the bar for the entire industry. They really move the needle on the user experience in subtle ways. Plus it's fun!
- **How:** Propose crazy ideas. See them through – ensure they get into the workflow and get resources allocated for them.

<!-- Paraphrased from Adlai's document @ https://usecanvas.com/anonymous/asdk-operating-basis/2yktS1l4LDGEq25JmwSdC3 -->