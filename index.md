---
layout: default
title: substrate
---

<section aria-label="Blog posts">
<h2>log</h2>

<ul class="post-list">
{% for post in site.posts %}
  <li>
    <time class="date" datetime="{{ post.date | date_to_xmlschema }}">{{ post.date | date: "%Y-%m-%d" }}</time><br>
    <a href="{{ post.url | prepend: site.baseurl }}">{{ post.title }}</a>
  </li>
{% endfor %}
</ul>
</section>
